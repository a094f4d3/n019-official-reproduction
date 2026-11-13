"""Training and inference code for the paper's Unit HiFi-GAN."""

from __future__ import annotations

import argparse
import faulthandler
import json
import math
import os
import random
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
import torch
import torch.distributed as dist
import torch.nn.functional as F
from torch.nn.parallel import DistributedDataParallel
from torch.utils.data import DataLoader, Dataset, DistributedSampler

from n019.audio import HOP_SAMPLES, load_audio_16k
from n019.hifigan import (
    GeneratorConfig,
    MultiPeriodDiscriminator,
    MultiScaleDiscriminator,
    UnitSpeakerHiFiGAN,
    discriminator_loss,
    feature_matching_loss,
    generator_loss,
)
from n019.manifest import (
    iter_jsonl,
    sha256_file,
    speaker_id,
    utterance_id,
    write_json,
)
from n019.spectral import mel_spectrogram
from n019.training_recipe import (
    validate_feature_matching_recipe,
    training_recipe_metadata,
)


@dataclass(frozen=True)
class UnitVocoderConfig:
    vocabulary_size: int = 201
    padding_unit_id: int = 200
    unit_embedding_dim: int = 128
    speaker_dim: int = 250
    speaker_projection_dim: int | None = None
    segment_frames: int = 28
    batch_size: int = 16
    learning_rate: float = 2e-4
    optimizer: str = "adamw"
    adam_beta1: float = 0.8
    adam_beta2: float = 0.99
    lr_decay: float = 0.999
    grad_clip_norm: float = 0.0
    steps: int = 400_000
    mel_loss_weight: float = 45.0
    feature_loss_weight: float = 1.0
    workers: int = 4
    seed: int = 20261102
    checkpoint_interval: int = 5_000
    generator_snapshot_interval: int = 10_000
    keep_interval: int = 25_000
    validation_interval: int = 1_000
    validation_limit: int = 64
    selection_policy: str = "mel_l1"
    early_stop_min_steps: int = 20_000
    early_stop_patience: int = 15
    early_stop_min_delta: float = 1e-3
    max_hours: float = 24.0
    bf16: bool = False
    embedding_level: str = "speaker"
    generator: GeneratorConfig = GeneratorConfig()


class UnitVocoderDataset(Dataset):
    def __init__(
        self,
        records_path: str | Path,
        embeddings_path: str | Path,
        *,
        segment_frames: int,
        padding_unit_id: int,
        embedding_level: str,
        random_crop: bool,
        seed: int,
        limit: int = 0,
    ) -> None:
        self.records = list(iter_jsonl(records_path))
        if limit:
            self.records = self.records[:limit]
        if not self.records:
            raise ValueError("Vocoder dataset is empty")
        archive = np.load(embeddings_path)
        self.embeddings = {
            key: torch.from_numpy(archive[key].astype(np.float32))
            for key in archive.files
        }
        archive.close()
        self.segment_frames = segment_frames
        self.padding_unit_id = padding_unit_id
        self.embedding_level = embedding_level
        self.random_crop = random_crop
        self.seed = seed
        self.epoch = 0

    def set_epoch(self, epoch: int) -> None:
        self.epoch = epoch

    def __len__(self) -> int:
        return len(self.records)

    def __getitem__(self, index: int):
        import librosa

        row = self.records[index]
        codes = np.load(row["codes_path"]).astype(np.int64, copy=False)
        if codes.size == 0:
            raise ValueError(f"Empty code sequence: {row['codes_path']}")
        if int(codes.min()) < 0 or int(codes.max()) >= self.padding_unit_id:
            raise ValueError(f"Invalid unit IDs in {row['codes_path']}")
        waveform = load_audio_16k(row["audio"]).numpy().astype(np.float32)
        code_frames = min(codes.size, waveform.size // HOP_SAMPLES)
        if code_frames <= 0:
            raise ValueError(f"No complete frames for {row['audio']}")
        codes = codes[:code_frames]
        waveform = waveform[: code_frames * HOP_SAMPLES]
        waveform = librosa.util.normalize(waveform) * 0.95
        while code_frames < self.segment_frames:
            codes = np.concatenate([codes, codes])
            waveform = np.concatenate([waveform, waveform])
            code_frames = min(codes.size, waveform.size // HOP_SAMPLES)
        if self.random_crop:
            generator = np.random.default_rng(
                self.seed + self.epoch * 1_000_003 + index
            )
            maximum_start = code_frames - self.segment_frames
            start = int(generator.integers(0, maximum_start + 1))
        else:
            start = max(0, (code_frames - self.segment_frames) // 2)
        codes = torch.from_numpy(
            codes[start : start + self.segment_frames].copy()
        ).long()
        waveform = waveform[
            start * HOP_SAMPLES : (start + self.segment_frames) * HOP_SAMPLES
        ].copy()
        key = speaker_id(row) if self.embedding_level == "speaker" else utterance_id(row)
        if key not in self.embeddings:
            raise KeyError(f"Missing speaker embedding key: {key}")
        return (
            codes,
            torch.from_numpy(waveform.astype(np.float32)),
            self.embeddings[key],
        )


def vocoder_collate(batch):
    codes, waveforms, speakers = zip(*batch)
    return torch.stack(codes), torch.stack(waveforms), torch.stack(speakers)


def build_models(
    config: UnitVocoderConfig,
    device: torch.device,
) -> tuple[UnitSpeakerHiFiGAN, MultiPeriodDiscriminator, MultiScaleDiscriminator]:
    generator = UnitSpeakerHiFiGAN(
        vocab_size=config.vocabulary_size,
        unit_embedding_dim=config.unit_embedding_dim,
        speaker_dim=config.speaker_dim,
        speaker_projection_dim=config.speaker_projection_dim,
        generator_config=config.generator,
        padding_idx=config.padding_unit_id,
    ).to(device)
    mpd = MultiPeriodDiscriminator().to(device)
    msd = MultiScaleDiscriminator().to(device)
    return generator, mpd, msd


def save_vocoder_checkpoint(
    path: str | Path,
    *,
    config: UnitVocoderConfig,
    generator: torch.nn.Module,
    mpd: torch.nn.Module,
    msd: torch.nn.Module,
    optimizer_g: torch.optim.Optimizer,
    optimizer_d: torch.optim.Optimizer,
    scheduler_g: torch.optim.lr_scheduler._LRScheduler | None,
    scheduler_d: torch.optim.lr_scheduler._LRScheduler | None,
    step: int,
    epoch: int,
    best_validation_mel_l1: float | None = None,
    best_validation_step: int = 0,
    validations_without_improvement: int = 0,
    stop_reason: str | None = None,
    selection_policy: str = "mel_l1",
    recipe: dict | None = None,
) -> None:
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    torch.save(
        {
            "config": asdict(config),
            "generator": generator.state_dict(),
            "mpd": mpd.state_dict(),
            "msd": msd.state_dict(),
            "optimizer_g": optimizer_g.state_dict(),
            "optimizer_d": optimizer_d.state_dict(),
            "scheduler_g": scheduler_g.state_dict() if scheduler_g else None,
            "scheduler_d": scheduler_d.state_dict() if scheduler_d else None,
            "step": step,
            "epoch": epoch,
            "best_validation_mel_l1": best_validation_mel_l1,
            "best_validation_step": best_validation_step,
            "validations_without_improvement": validations_without_improvement,
            "stop_reason": stop_reason,
            "selection_policy": selection_policy,
            "recipe": recipe,
        },
        temporary,
    )
    os.replace(temporary, destination)


def save_generator_checkpoint(
    path: str | Path,
    *,
    config: UnitVocoderConfig,
    generator: torch.nn.Module,
    step: int,
    epoch: int,
    validation_mel_l1: float,
    selection_policy: str = "mel_l1",
    recipe: dict | None = None,
) -> None:
    """Save a compact generator-only checkpoint for inference and transfer."""
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    torch.save(
        {
            "config": asdict(config),
            "generator": generator.state_dict(),
            "step": step,
            "epoch": epoch,
            "validation_mel_l1": validation_mel_l1,
            "selection_policy": selection_policy,
            "recipe": recipe,
        },
        temporary,
    )
    os.replace(temporary, destination)


def update_validation_best(
    *,
    metric: float,
    step: int,
    best_metric: float | None,
    best_step: int,
    validations_without_improvement: int,
    min_delta: float,
) -> tuple[float, int, int, bool]:
    """Update best validation state; lower mel L1 is better."""
    if not math.isfinite(metric):
        raise ValueError("Validation metric must be finite")
    if step < 0 or best_step < 0 or validations_without_improvement < 0:
        raise ValueError("Validation counters must be non-negative")
    if min_delta < 0.0:
        raise ValueError("Validation min_delta must be non-negative")
    improved = best_metric is None or metric < best_metric - min_delta
    if improved:
        return metric, step, 0, True
    return (
        float(best_metric),
        best_step,
        validations_without_improvement + 1,
        False,
    )


def validation_converged(
    *,
    step: int,
    validations_without_improvement: int,
    patience: int,
    min_steps: int,
) -> bool:
    if min(step, validations_without_improvement, patience, min_steps) < 0:
        raise ValueError("Convergence settings must be non-negative")
    return (
        patience > 0
        and step >= min_steps
        and validations_without_improvement >= patience
    )


def load_generator(
    path: str | Path,
    device: torch.device,
) -> tuple[UnitSpeakerHiFiGAN, dict]:
    checkpoint = torch.load(path, map_location=device, weights_only=False)
    raw = checkpoint["config"]
    raw["generator"] = GeneratorConfig(**raw["generator"])
    config = UnitVocoderConfig(**raw)
    generator = UnitSpeakerHiFiGAN(
        vocab_size=config.vocabulary_size,
        unit_embedding_dim=config.unit_embedding_dim,
        speaker_dim=config.speaker_dim,
        speaker_projection_dim=config.speaker_projection_dim,
        generator_config=config.generator,
        padding_idx=config.padding_unit_id,
    ).to(device)
    generator.load_state_dict(checkpoint["generator"])
    generator.eval()
    return generator, checkpoint


def reduce_scalar(value: torch.Tensor) -> torch.Tensor:
    if dist.is_available() and dist.is_initialized():
        dist.all_reduce(value, op=dist.ReduceOp.SUM)
        value /= dist.get_world_size()
    return value


def ddp_enabled() -> bool:
    return int(os.environ.get("WORLD_SIZE", "1")) > 1


def setup_distributed(device_argument: str) -> tuple[torch.device, int, int]:
    if not ddp_enabled():
        if device_argument == "cuda" and not torch.cuda.is_available():
            raise RuntimeError("CUDA/DCU requested but unavailable")
        return torch.device(device_argument), 0, 1
    if not torch.cuda.is_available():
        raise RuntimeError("DDP training requires CUDA/DCU")
    local_rank = int(os.environ["LOCAL_RANK"])
    torch.cuda.set_device(local_rank)
    dist.init_process_group(backend="nccl")
    return torch.device("cuda", local_rank), local_rank, dist.get_world_size()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train a Unit HiFi-GAN conditioned on NT or ECAPA embeddings."
    )
    parser.add_argument("--records", required=True)
    parser.add_argument("--embeddings", required=True)
    parser.add_argument("--validation-records", default=None)
    parser.add_argument("--validation-embeddings", default=None)
    parser.add_argument("--out", required=True)
    parser.add_argument("--speaker-dim", type=int, choices=[192, 250], required=True)
    parser.add_argument("--embedding-level", choices=["speaker", "utterance"], default="speaker")
    parser.add_argument("--segment-frames", type=int, default=28)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--steps", type=int, default=400_000)
    parser.add_argument("--lr", type=float, default=2e-4)
    parser.add_argument(
        "--optimizer",
        choices=["adam", "adamw"],
        default="adamw",
        help=(
            "Use adamw to match speech-resynthesis commit dbb92c8d, or adam "
            "only for an explicitly labeled diagnostic."
        ),
    )
    parser.add_argument(
        "--grad-clip-norm",
        type=float,
        default=0.0,
        help="Clip generator gradients to this norm; 0 disables clipping.",
    )
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--checkpoint-interval", type=int, default=5_000)
    parser.add_argument(
        "--generator-snapshot-interval",
        type=int,
        default=10_000,
        help=(
            "Save compact generator_stepXXXXXXXX.pt snapshots at this interval; "
            "set 0 to disable."
        ),
    )
    parser.add_argument("--keep-interval", type=int, default=25_000)
    parser.add_argument("--validation-interval", type=int, default=1_000)
    parser.add_argument(
        "--validation-limit",
        type=int,
        default=64,
        help="Maximum monitoring utterances; 0 uses all supplied validation rows.",
    )
    parser.add_argument("--early-stop-min-steps", type=int, default=20_000)
    parser.add_argument("--early-stop-patience", type=int, default=15)
    parser.add_argument("--early-stop-min-delta", type=float, default=1e-3)
    parser.add_argument(
        "--selection-policy",
        choices=["mel_l1", "mos_offline"],
        default="mel_l1",
        help=(
            "mel_l1 preserves the historical monitor/best.pt behavior. "
            "mos_offline disables mel-based early stopping and best.pt "
            "selection; snapshots must be ranked by the offline MOS selector."
        ),
    )
    parser.add_argument("--max-hours", type=float, default=24.0)
    parser.add_argument(
        "--resume-converged",
        action="store_true",
        help="Allow resuming a run whose last checkpoint already converged.",
    )
    parser.add_argument(
        "--init-generator",
        default=None,
        help=(
            "Initialize a new run from a compact generator-only checkpoint. "
            "Discriminators and optimizers start from scratch."
        ),
    )
    parser.add_argument(
        "--init-generator-sha256",
        default=None,
        help="Required SHA256 gate for --init-generator.",
    )
    parser.add_argument(
        "--allow-recipe-change",
        action="store_true",
        help=(
            "Allow resuming a checkpoint with a different recorded training "
            "recipe. Use only for an explicitly labeled diagnostic."
        ),
    )
    parser.add_argument("--seed", type=int, default=20261102)
    parser.add_argument("--device", default="cuda")
    parser.add_argument("--bf16", action="store_true")
    return parser.parse_args()


def output_directory_conflicts(out: Path) -> list[str]:
    if not out.exists():
        return []
    if (out / "last.pt").is_file():
        return []
    return sorted(path.name for path in out.iterdir() if path.name != "launch.txt")


_STAGE_TRACE = os.environ.get("N019_STAGE_TRACE", "0") == "1"


def stage(name: str) -> None:
    """Emit a flushed startup/loop marker when N019_STAGE_TRACE=1."""
    if _STAGE_TRACE:
        print(f"STAGE {name} {time.strftime('%Y-%m-%dT%H:%M:%S')}", flush=True)


def main() -> int:
    stack_dump_seconds = os.environ.get("N019_STACK_DUMP_SECONDS")
    if stack_dump_seconds:
        faulthandler.dump_traceback_later(
            float(stack_dump_seconds),
            repeat=True,
        )
    args = parse_args()
    validate_feature_matching_recipe()
    stage("args_validated")
    if args.steps <= 0:
        raise ValueError("--steps must be positive")
    if args.batch_size <= 0:
        raise ValueError("--batch-size must be positive")
    if args.segment_frames <= 0:
        raise ValueError("--segment-frames must be positive")
    if args.lr <= 0.0:
        raise ValueError("--lr must be positive")
    if args.grad_clip_norm < 0.0:
        raise ValueError("--grad-clip-norm must be non-negative")
    if args.checkpoint_interval <= 0 or args.validation_interval <= 0:
        raise ValueError("checkpoint and validation intervals must be positive")
    if args.generator_snapshot_interval < 0:
        raise ValueError("--generator-snapshot-interval must be non-negative")
    if bool(args.validation_records) != bool(args.validation_embeddings):
        raise ValueError(
            "--validation-records and --validation-embeddings must be given together"
        )
    if args.validation_limit < 0:
        raise ValueError("--validation-limit must be non-negative")
    if args.early_stop_min_steps < 0:
        raise ValueError("--early-stop-min-steps must be non-negative")
    if args.early_stop_patience < 0:
        raise ValueError("--early-stop-patience must be non-negative")
    if args.early_stop_min_delta < 0.0:
        raise ValueError("--early-stop-min-delta must be non-negative")
    if args.max_hours <= 0.0:
        raise ValueError("--max-hours must be positive")
    out = Path(args.out)
    last_checkpoint = out / "last.pt"
    if args.init_generator and last_checkpoint.is_file():
        raise ValueError(
            "--init-generator is only valid for a new run without last.pt"
        )
    conflicts = output_directory_conflicts(out)
    if conflicts:
        raise FileExistsError(
            "Output directory has files other than launch.txt and no last.pt: "
            f"{out}; conflicts={conflicts}"
        )
    out.mkdir(parents=True, exist_ok=True)
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(args.seed)
        # DTK/hipDNN autotuning has produced unstable first-kernel behavior
        # on SCNet. Benchmark mode is a performance-only optimization, so keep
        # it opt-in via N019_CUDNN_BENCHMARK=1.
        torch.backends.cudnn.benchmark = (
            os.environ.get("N019_CUDNN_BENCHMARK", "0") == "1"
        )
    device, rank, world_size = setup_distributed(args.device)
    is_main = rank == 0
    stage(f"distributed_ready:{device}:{world_size}")
    config = UnitVocoderConfig(
        speaker_dim=args.speaker_dim,
        segment_frames=args.segment_frames,
        batch_size=args.batch_size,
        learning_rate=args.lr,
        optimizer=args.optimizer,
        grad_clip_norm=args.grad_clip_norm,
        steps=args.steps,
        workers=args.workers,
        seed=args.seed,
        checkpoint_interval=args.checkpoint_interval,
        generator_snapshot_interval=args.generator_snapshot_interval,
        keep_interval=args.keep_interval,
        validation_interval=args.validation_interval,
        validation_limit=args.validation_limit,
        selection_policy=args.selection_policy,
        early_stop_min_steps=args.early_stop_min_steps,
        early_stop_patience=args.early_stop_patience,
        early_stop_min_delta=args.early_stop_min_delta,
        max_hours=args.max_hours,
        bf16=args.bf16,
        embedding_level=args.embedding_level,
    )
    train_dataset = UnitVocoderDataset(
        args.records,
        args.embeddings,
        segment_frames=config.segment_frames,
        padding_unit_id=config.padding_unit_id,
        embedding_level=config.embedding_level,
        random_crop=True,
        seed=config.seed,
    )
    stage(f"train_dataset_ready:{len(train_dataset)}")
    validation_records = args.validation_records or args.records
    validation_embeddings = args.validation_embeddings or args.embeddings
    validation_dataset = UnitVocoderDataset(
        validation_records,
        validation_embeddings,
        segment_frames=config.segment_frames,
        padding_unit_id=config.padding_unit_id,
        embedding_level=config.embedding_level,
        random_crop=False,
        seed=config.seed + 1,
        limit=config.validation_limit,
    )
    stage(f"validation_dataset_ready:{len(validation_dataset)}")
    train_sampler = (
        DistributedSampler(train_dataset, shuffle=True, seed=config.seed)
        if world_size > 1
        else None
    )
    validation_sampler = (
        DistributedSampler(validation_dataset, shuffle=False)
        if world_size > 1
        else None
    )
    pin_memory = os.environ.get("N019_PIN_MEMORY", "0") == "1"
    train_loader = DataLoader(
        train_dataset,
        batch_size=config.batch_size,
        shuffle=train_sampler is None,
        sampler=train_sampler,
        num_workers=config.workers,
        collate_fn=vocoder_collate,
        pin_memory=pin_memory,
        drop_last=len(train_dataset) >= config.batch_size,
        persistent_workers=config.workers > 0,
    )
    validation_loader = DataLoader(
        validation_dataset,
        batch_size=config.batch_size,
        shuffle=False,
        sampler=validation_sampler,
        num_workers=config.workers,
        collate_fn=vocoder_collate,
        pin_memory=pin_memory,
        drop_last=False,
        persistent_workers=config.workers > 0,
    )
    stage("dataloaders_ready")
    generator, mpd, msd = build_models(config, device)
    stage("models_built")
    recipe = training_recipe_metadata()
    initialized_from = None
    if args.init_generator:
        init_path = Path(args.init_generator)
        if not init_path.is_file():
            raise FileNotFoundError(init_path)
        init_sha = sha256_file(init_path)
        if (
            args.init_generator_sha256
            and init_sha != args.init_generator_sha256
        ):
            raise RuntimeError(
                f"Initial generator SHA256 mismatch: {init_sha} != "
                f"{args.init_generator_sha256}"
            )
        init_checkpoint = torch.load(
            init_path,
            map_location=device,
            weights_only=False,
        )
        init_config = init_checkpoint.get("config")
        current_config = asdict(config)
        architecture_keys = (
            "vocabulary_size",
            "padding_unit_id",
            "unit_embedding_dim",
            "speaker_dim",
            "speaker_projection_dim",
            "generator",
        )
        if init_config is None or any(
            init_config.get(key) != current_config.get(key)
            for key in architecture_keys
        ):
            raise ValueError(
                "Initial generator architecture does not match vocoder args"
            )
        generator.load_state_dict(init_checkpoint["generator"])
        initialized_from = {
            "path": str(init_path.resolve()),
            "sha256": init_sha,
            "step": init_checkpoint.get("step"),
            "recipe": init_checkpoint.get("recipe"),
        }
    optimizer_class = (
        torch.optim.Adam if config.optimizer == "adam" else torch.optim.AdamW
    )
    optimizer_g = optimizer_class(
        generator.parameters(),
        lr=config.learning_rate,
        betas=(config.adam_beta1, config.adam_beta2),
    )
    optimizer_d = optimizer_class(
        list(mpd.parameters()) + list(msd.parameters()),
        lr=config.learning_rate,
        betas=(config.adam_beta1, config.adam_beta2),
    )
    scheduler_g = torch.optim.lr_scheduler.ExponentialLR(
        optimizer_g,
        gamma=config.lr_decay,
    )
    scheduler_d = torch.optim.lr_scheduler.ExponentialLR(
        optimizer_d,
        gamma=config.lr_decay,
    )
    resume_step = 0
    resume_epoch = 0
    best_validation_mel_l1: float | None = None
    best_validation_step = 0
    validations_without_improvement = 0
    saved_stop_reason: str | None = None
    if last_checkpoint.is_file():
        checkpoint = torch.load(
            last_checkpoint,
            map_location=device,
            weights_only=False,
        )
        saved_config = checkpoint.get("config")
        current_config = asdict(config)
        architecture_keys = (
            "vocabulary_size",
            "padding_unit_id",
            "unit_embedding_dim",
            "speaker_dim",
            "speaker_projection_dim",
            "generator",
        )
        if saved_config is None or any(
            saved_config.get(key) != current_config.get(key)
            for key in architecture_keys
        ):
            raise ValueError(
                "Checkpoint architecture does not match current vocoder args"
            )
        saved_recipe = checkpoint.get("recipe")
        if (
            saved_recipe is not None
            and saved_recipe != recipe
            and not args.allow_recipe_change
        ):
            raise RuntimeError(
                "Checkpoint recipe differs from the deployed training recipe; "
                "pass --allow-recipe-change only for a labeled diagnostic"
            )
        generator.load_state_dict(checkpoint["generator"])
        mpd.load_state_dict(checkpoint["mpd"])
        msd.load_state_dict(checkpoint["msd"])
        optimizer_g.load_state_dict(checkpoint["optimizer_g"])
        optimizer_d.load_state_dict(checkpoint["optimizer_d"])
        if checkpoint.get("scheduler_g") and checkpoint.get("scheduler_d"):
            scheduler_g.load_state_dict(checkpoint["scheduler_g"])
            scheduler_d.load_state_dict(checkpoint["scheduler_d"])
        resume_step = int(checkpoint["step"]) + 1
        resume_epoch = int(checkpoint.get("epoch", 0))
        raw_best = checkpoint.get("best_validation_mel_l1")
        best_validation_mel_l1 = (
            float(raw_best) if raw_best is not None else None
        )
        best_validation_step = int(checkpoint.get("best_validation_step", 0))
        validations_without_improvement = int(
            checkpoint.get("validations_without_improvement", 0)
        )
        saved_stop_reason = checkpoint.get("stop_reason")
        if saved_stop_reason == "converged" and not args.resume_converged:
            if is_main:
                print(
                    json.dumps(
                        {
                            "status": "already_converged",
                            "step": int(checkpoint["step"]),
                            "best_validation_mel_l1": best_validation_mel_l1,
                            "best_validation_step": best_validation_step,
                        }
                    ),
                    flush=True,
                )
            if dist.is_available() and dist.is_initialized():
                dist.destroy_process_group()
            return 0
    if world_size > 1:
        generator = DistributedDataParallel(
            generator,
            device_ids=[device.index],
            output_device=device.index,
        )
        mpd = DistributedDataParallel(
            mpd,
            device_ids=[device.index],
            output_device=device.index,
        )
        msd = DistributedDataParallel(
            msd,
            device_ids=[device.index],
            output_device=device.index,
        )

    if is_main:
        write_json(
            out / "meta.json",
            {
                "config": asdict(config),
                "recipe": recipe,
                "train_records": len(train_dataset),
                "validation_records": len(validation_dataset),
                "validation_source": (
                    args.validation_records
                    if args.validation_records
                    else "training records (monitoring only)"
                ),
                "input_sha256": {
                    "records": sha256_file(args.records),
                    "embeddings": sha256_file(args.embeddings),
                    **(
                        {
                            "validation_records": sha256_file(
                                args.validation_records
                            ),
                            "validation_embeddings": sha256_file(
                                args.validation_embeddings
                            ),
                        }
                        if args.validation_records
                        else {}
                    ),
                },
                "world_size": world_size,
                "resumed_from": str(last_checkpoint) if resume_step else None,
                "initialized_from": initialized_from,
                "resume_recipe_missing": bool(
                    resume_step and checkpoint.get("recipe") is None
                ),
            },
        )
    generator_module = generator.module if world_size > 1 else generator
    mpd_module = mpd.module if world_size > 1 else mpd
    msd_module = msd.module if world_size > 1 else msd
    log_path = out / "training_log.jsonl"
    log_handle = log_path.open("a", encoding="utf-8") if is_main else None
    started = time.time()
    step = resume_step
    epoch = resume_epoch
    stop_reason: str | None = None
    trace_first_batch = True
    stage(f"training_loop_start:step={resume_step}")
    while step < config.steps:
        if train_sampler is not None:
            train_sampler.set_epoch(epoch)
        train_dataset.set_epoch(epoch)
        generator.train()
        mpd.train()
        msd.train()
        for codes, waveform, speaker in train_loader:
            if trace_first_batch:
                stage(
                    "first_batch_fetched:"
                    f"codes={tuple(codes.shape)}:waveform={tuple(waveform.shape)}"
                )
            codes = codes.to(device, non_blocking=True)
            waveform = waveform.to(device, non_blocking=True)
            speaker = speaker.to(device, non_blocking=True)
            real = waveform.unsqueeze(1)
            if trace_first_batch:
                stage("first_batch_on_device")
            batch_started = time.time()
            autocast_enabled = config.bf16 and device.type == "cuda"
            with torch.autocast(
                device_type="cuda",
                dtype=torch.bfloat16,
                enabled=autocast_enabled,
            ):
                generated = generator(codes, speaker)
            if trace_first_batch:
                stage(f"first_generator_forward:{tuple(generated.shape)}")
            expected_samples = codes.shape[1] * config.generator.samples_per_frame
            if generated.shape != (codes.shape[0], 1, expected_samples):
                raise RuntimeError(
                    f"Unexpected generated shape {tuple(generated.shape)} for "
                    f"{codes.shape[0]} x {codes.shape[1]} units"
                )
            with torch.autocast(
                device_type="cuda",
                dtype=torch.bfloat16,
                enabled=autocast_enabled,
            ):
                real_f, generated_f, _, _ = mpd(real, generated.detach().float())
                loss_d_period = discriminator_loss(real_f, generated_f)
                real_s, generated_s, _, _ = msd(real, generated.detach().float())
                loss_d_scale = discriminator_loss(real_s, generated_s)
            loss_d = loss_d_period + loss_d_scale
            if not bool(torch.isfinite(loss_d)):
                raise RuntimeError(f"Non-finite discriminator loss at step {step + 1}")
            optimizer_d.zero_grad(set_to_none=True)
            loss_d.backward()
            optimizer_d.step()
            if trace_first_batch:
                stage("first_discriminator_step")
            optimizer_d.zero_grad(set_to_none=True)

            with torch.autocast(
                device_type="cuda",
                dtype=torch.bfloat16,
                enabled=autocast_enabled,
            ):
                real_f, generated_f, feature_real_f, feature_gen_f = mpd(
                    real,
                    generated.float(),
                )
                real_s, generated_s, feature_real_s, feature_gen_s = msd(
                    real,
                    generated.float(),
                )
                # HIPFFT rejects BF16 STFT on the SCNet DTK build. Compute the
                # spectral loss in FP32 even when the adversarial path uses
                # autocast; this also matches the reference implementation.
                with torch.autocast(
                    device_type="cuda",
                    dtype=torch.bfloat16,
                    enabled=False,
                ):
                    mel_real = mel_spectrogram(real.squeeze(1))
                    mel_generated = mel_spectrogram(
                        generated.squeeze(1).float()
                    )
                    mel_loss = (
                        F.l1_loss(mel_real, mel_generated)
                        * config.mel_loss_weight
                    )
                loss_g = (
                    generator_loss(generated_f)
                    + generator_loss(generated_s)
                    + config.feature_loss_weight
                    * feature_matching_loss(feature_real_f, feature_gen_f)
                    + config.feature_loss_weight
                    * feature_matching_loss(feature_real_s, feature_gen_s)
                    + mel_loss
                )
            if not bool(torch.isfinite(loss_g)):
                raise RuntimeError(f"Non-finite generator loss at step {step + 1}")
            optimizer_g.zero_grad(set_to_none=True)
            loss_g.backward()
            if trace_first_batch:
                stage("first_generator_backward")
            if config.grad_clip_norm > 0.0:
                torch.nn.utils.clip_grad_norm_(
                    generator.parameters(),
                    config.grad_clip_norm,
                )
            optimizer_g.step()
            step += 1
            if trace_first_batch:
                trace_first_batch = False
                stage(f"first_generator_step_done:step={step}")
            loss_d_value = reduce_scalar(loss_d.detach())
            loss_g_value = reduce_scalar(loss_g.detach())
            mel_value = reduce_scalar(mel_loss.detach())
            if not bool(torch.isfinite(loss_d_value)):
                raise RuntimeError(f"Non-finite discriminator loss at step {step}")
            if not bool(torch.isfinite(loss_g_value)):
                raise RuntimeError(f"Non-finite generator loss at step {step}")
            if is_main and (step == 1 or step % 20 == 0):
                row = {
                    "step": step,
                    "loss_d": float(loss_d_value),
                    "loss_g": float(loss_g_value),
                    "mel_loss": float(mel_value),
                    "seconds": time.time() - batch_started,
                    "elapsed_hours": (time.time() - started) / 3600,
                    "lr_g": optimizer_g.param_groups[0]["lr"],
                    "lr_d": optimizer_d.param_groups[0]["lr"],
                }
                print(json.dumps(row), flush=True)
                assert log_handle is not None
                log_handle.write(json.dumps(row) + "\n")
                log_handle.flush()

            if (
                is_main
                and config.generator_snapshot_interval > 0
                and step % config.generator_snapshot_interval == 0
            ):
                save_generator_checkpoint(
                    out
                    / "snapshots"
                    / f"generator_step{step:08d}.pt",
                    config=config,
                    generator=generator_module,
                    step=step,
                    epoch=epoch,
                    validation_mel_l1=(
                        best_validation_mel_l1
                        if best_validation_mel_l1 is not None
                        else math.nan
                    ),
                    selection_policy=config.selection_policy,
                    recipe=recipe,
                )

            if step % config.validation_interval == 0:
                generator.eval()
                mpd.eval()
                msd.eval()
                validation_mel = torch.zeros((), device=device)
                validation_batches = 0
                with torch.inference_mode():
                    for val_codes, val_waveform, val_speaker in validation_loader:
                        val_codes = val_codes.to(device, non_blocking=True)
                        val_waveform = val_waveform.to(device, non_blocking=True)
                        val_speaker = val_speaker.to(device, non_blocking=True)
                        val_generated = generator(val_codes, val_speaker)
                        validation_mel += F.l1_loss(
                            mel_spectrogram(val_waveform.unsqueeze(1).squeeze(1)),
                            mel_spectrogram(val_generated.squeeze(1).float()),
                        )
                        validation_batches += 1
                validation_mel = reduce_scalar(
                    validation_mel / max(1, validation_batches)
                )
                validation_value = float(validation_mel)
                (
                    best_validation_mel_l1,
                    best_validation_step,
                    validations_without_improvement,
                    validation_improved,
                ) = update_validation_best(
                    metric=validation_value,
                    step=step,
                    best_metric=best_validation_mel_l1,
                    best_step=best_validation_step,
                    validations_without_improvement=validations_without_improvement,
                    min_delta=config.early_stop_min_delta,
                )
                if is_main:
                    validation_row = {
                        "step": step,
                        "validation_mel_l1": validation_value,
                        "best_validation_mel_l1": best_validation_mel_l1,
                        "best_validation_step": best_validation_step,
                        "validations_without_improvement": (
                            validations_without_improvement
                        ),
                        "validation_improved": validation_improved,
                        "selection_policy": config.selection_policy,
                    }
                    print(json.dumps(validation_row), flush=True)
                    assert log_handle is not None
                    log_handle.write(json.dumps(validation_row) + "\n")
                    log_handle.flush()
                    if (
                        config.selection_policy == "mel_l1"
                        and validation_improved
                    ):
                        save_generator_checkpoint(
                            out / "best.pt",
                            config=config,
                            generator=generator_module,
                            step=step,
                            epoch=epoch,
                            validation_mel_l1=validation_value,
                            selection_policy=config.selection_policy,
                            recipe=recipe,
                        )
                if (
                    config.selection_policy == "mel_l1"
                    and validation_converged(
                        step=step,
                        validations_without_improvement=(
                            validations_without_improvement
                        ),
                        patience=config.early_stop_patience,
                        min_steps=config.early_stop_min_steps,
                    )
                ):
                    stop_reason = "converged"
                    if is_main:
                        assert log_handle is not None
                        convergence_row = {
                            "step": step,
                            "event": "converged",
                            "best_validation_mel_l1": best_validation_mel_l1,
                            "best_validation_step": best_validation_step,
                            "validations_without_improvement": (
                                validations_without_improvement
                            ),
                            "early_stop_min_steps": (
                                config.early_stop_min_steps
                            ),
                            "early_stop_patience": config.early_stop_patience,
                            "early_stop_min_delta": (
                                config.early_stop_min_delta
                            ),
                        }
                        print(json.dumps(convergence_row), flush=True)
                        log_handle.write(json.dumps(convergence_row) + "\n")
                        log_handle.flush()
                generator.train()
                mpd.train()
                msd.train()

            if step % config.checkpoint_interval == 0:
                if world_size > 1:
                    dist.barrier()
                if is_main:
                    save_vocoder_checkpoint(
                        last_checkpoint,
                        config=config,
                        generator=generator_module,
                        mpd=mpd_module,
                        msd=msd_module,
                        optimizer_g=optimizer_g,
                        optimizer_d=optimizer_d,
                        scheduler_g=scheduler_g,
                        scheduler_d=scheduler_d,
                        step=step,
                        epoch=epoch,
                        best_validation_mel_l1=best_validation_mel_l1,
                        best_validation_step=best_validation_step,
                        validations_without_improvement=(
                            validations_without_improvement
                        ),
                        stop_reason=stop_reason,
                        selection_policy=config.selection_policy,
                        recipe=recipe,
                    )
                    if step % config.keep_interval == 0:
                        save_vocoder_checkpoint(
                            out / f"checkpoint_{step:08d}.pt",
                            config=config,
                            generator=generator_module,
                            mpd=mpd_module,
                            msd=msd_module,
                            optimizer_g=optimizer_g,
                            optimizer_d=optimizer_d,
                            scheduler_g=scheduler_g,
                            scheduler_d=scheduler_d,
                            step=step,
                            epoch=epoch,
                            best_validation_mel_l1=best_validation_mel_l1,
                            best_validation_step=best_validation_step,
                            validations_without_improvement=(
                                validations_without_improvement
                            ),
                            stop_reason=stop_reason,
                            selection_policy=config.selection_policy,
                            recipe=recipe,
                        )
                if world_size > 1:
                    dist.barrier()
            if stop_reason == "converged":
                break
            if step >= config.steps:
                stop_reason = "max_steps"
                break
            if (time.time() - started) / 3600 >= config.max_hours:
                stop_reason = "max_hours"
                break
        if stop_reason is not None:
            break
        scheduler_g.step()
        scheduler_d.step()
        epoch += 1
        if (time.time() - started) / 3600 >= config.max_hours:
            stop_reason = "max_hours"
            break
    if world_size > 1:
        dist.barrier()
    if is_main:
        save_vocoder_checkpoint(
            last_checkpoint,
            config=config,
            generator=generator_module,
            mpd=mpd_module,
            msd=msd_module,
            optimizer_g=optimizer_g,
            optimizer_d=optimizer_d,
            scheduler_g=scheduler_g,
            scheduler_d=scheduler_d,
            step=step - 1,
            epoch=epoch,
            best_validation_mel_l1=best_validation_mel_l1,
            best_validation_step=best_validation_step,
            validations_without_improvement=(
                validations_without_improvement
            ),
            stop_reason=stop_reason,
            selection_policy=config.selection_policy,
            recipe=recipe,
        )
        if log_handle is not None:
            log_handle.close()
    if dist.is_available() and dist.is_initialized():
        dist.destroy_process_group()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
