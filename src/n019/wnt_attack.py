"""Fine-tune the W-NT attacker on an anonymised LS360 training set."""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import shutil
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
import torch
import torch.distributed as dist
import torch.nn.functional as F
from torch import nn
from torch.nn.parallel import DistributedDataParallel
from torch.utils.data import DataLoader, Dataset, DistributedSampler

from n019.audio import SAMPLE_RATE, load_audio_16k
from n019.manifest import sha256_file, write_json


@dataclass(frozen=True)
class WntAttackConfig:
    base_model: str
    train_data_dir: str
    output_dir: str
    expected_utterances: int = 104_014
    expected_speakers: int = 921
    segment_seconds: float = 3.0
    max_samples: int = 320_000
    batch_size: int = 8
    epochs: int = 20
    learning_rate: float = 1e-4
    head_learning_rate: float = 1e-4
    weight_decay: float = 2e-6
    gradient_clip: float = 5.0
    aam_margin: float = 0.2
    aam_scale: float = 30.0
    freeze_wavlm: bool = False
    workers: int = 4
    max_hours: float = 24.0
    checkpoint_interval: int = 500
    seed: int = 20261102
    bf16: bool = False


def read_kaldi_map(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    with path.open(encoding="utf-8") as handle:
        for line_number, raw in enumerate(handle, 1):
            fields = raw.strip().split(maxsplit=1)
            if len(fields) != 2:
                raise ValueError(f"Invalid entry at {path}:{line_number}")
            identifier, value = fields
            if identifier in result:
                raise ValueError(f"Duplicate key {identifier} in {path}")
            result[identifier] = value
    return result


def resolve_audio(data_dir: Path, value: str) -> Path:
    if value.strip().endswith("|"):
        raise ValueError(
            f"W-NT attack training requires materialised WAVs: {value}"
        )
    raw = Path(value)
    candidates = [raw] if raw.is_absolute() else [
        data_dir / raw,
        data_dir.parent / raw,
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    raise FileNotFoundError(
        f"Cannot resolve {value!r} from {data_dir}"
    )


def load_kaldi_rows(data_dir: Path) -> tuple[list[dict], list[str]]:
    wav_scp = data_dir / "wav.scp"
    utt2spk_path = data_dir / "utt2spk"
    wavs = read_kaldi_map(wav_scp)
    utt2spk = read_kaldi_map(utt2spk_path)
    missing_labels = sorted(set(wavs) - set(utt2spk))
    missing_audio = sorted(set(utt2spk) - set(wavs))
    if missing_labels or missing_audio:
        raise ValueError(
            f"wav.scp/utt2spk mismatch: "
            f"missing_labels={missing_labels[:3]}, "
            f"missing_audio={missing_audio[:3]}"
        )
    speakers = sorted(set(utt2spk.values()))
    speaker_to_index = {speaker: index for index, speaker in enumerate(speakers)}
    rows = [
        {
            "id": identifier,
            "speaker": utt2spk[identifier],
            "speaker_index": speaker_to_index[utt2spk[identifier]],
            "audio": str(resolve_audio(data_dir, wavs[identifier])),
        }
        for identifier in sorted(wavs)
    ]
    return rows, speakers


def crop_or_tile(
    waveform: torch.Tensor,
    *,
    samples: int,
    start: int,
) -> torch.Tensor:
    if samples <= 0:
        raise ValueError("samples must be positive")
    waveform = waveform.flatten()
    if waveform.numel() == 0:
        raise ValueError("Cannot crop empty audio")
    if waveform.numel() < samples:
        repeats = math.ceil(samples / waveform.numel())
        waveform = waveform.repeat(repeats)
    if start < 0:
        raise ValueError("start must be non-negative")
    maximum = waveform.numel() - samples
    start = min(start, maximum)
    return waveform[start : start + samples].contiguous()


class KaldiAttackDataset(Dataset):
    def __init__(
        self,
        rows: list[dict],
        *,
        samples: int,
        max_samples: int,
        seed: int,
    ) -> None:
        if not rows:
            raise ValueError("W-NT attack dataset is empty")
        self.rows = rows
        self.samples = samples
        self.max_samples = max_samples
        self.seed = seed
        self.epoch = 0

    def __len__(self) -> int:
        return len(self.rows)

    def set_epoch(self, epoch: int) -> None:
        self.epoch = epoch

    def __getitem__(self, index: int) -> tuple[torch.Tensor, int]:
        row = self.rows[index]
        waveform = load_audio_16k(row["audio"])
        if waveform.numel() > self.max_samples:
            waveform = waveform[: self.max_samples]
        available = max(1, waveform.numel() - self.samples + 1)
        generator = np.random.default_rng(
            self.seed + self.epoch * 1_000_003 + index
        )
        start = int(generator.integers(0, available))
        waveform = crop_or_tile(
            waveform,
            samples=self.samples,
            start=start,
        )
        return waveform, int(row["speaker_index"])


class AngularMarginHead(nn.Module):
    def __init__(
        self,
        embedding_dim: int,
        num_speakers: int,
        *,
        margin: float,
        scale: float,
    ) -> None:
        super().__init__()
        if embedding_dim <= 0 or num_speakers <= 0:
            raise ValueError("Embedding and speaker dimensions must be positive")
        if not 0.0 <= margin < math.pi / 2:
            raise ValueError("AAM margin must be in [0, pi/2)")
        if scale <= 0.0:
            raise ValueError("AAM scale must be positive")
        self.weight = nn.Parameter(torch.empty(num_speakers, embedding_dim))
        nn.init.xavier_uniform_(self.weight)
        self.margin = float(margin)
        self.scale = float(scale)

    def forward(
        self,
        embeddings: torch.Tensor,
        labels: torch.Tensor,
    ) -> torch.Tensor:
        if embeddings.ndim != 2 or embeddings.shape[1] != self.weight.shape[1]:
            raise ValueError("Unexpected embedding shape for AAM head")
        cosine = F.linear(
            F.normalize(embeddings, dim=1),
            F.normalize(self.weight, dim=1),
        ).clamp(-1.0 + 1e-7, 1.0 - 1e-7)
        target = cosine.gather(1, labels.unsqueeze(1))
        target = torch.cos(torch.acos(target) + self.margin)
        one_hot = torch.zeros_like(cosine).scatter_(1, labels.unsqueeze(1), 1.0)
        logits = cosine * (1.0 - one_hot) + target * one_hot
        return logits * self.scale


class WntClassifier(nn.Module):
    """Join the W-PRO encoder and AAM head for DDP and optimizer ownership."""

    def __init__(self, model: nn.Module, head: AngularMarginHead) -> None:
        super().__init__()
        self.model = model
        self.head = head

    def forward(
        self,
        waveforms: torch.Tensor,
        labels: torch.Tensor,
    ) -> torch.Tensor:
        return self.head(self.model(waveforms), labels)


def ddp_enabled() -> bool:
    return int(os.environ.get("WORLD_SIZE", "1")) > 1


def setup_distributed(device_argument: str) -> tuple[torch.device, int, int]:
    if not ddp_enabled():
        if device_argument == "cuda" and not torch.cuda.is_available():
            raise RuntimeError("CUDA/DCU requested but unavailable")
        return torch.device(device_argument), 0, 1
    if not torch.cuda.is_available():
        raise RuntimeError("DDP W-NT training requires CUDA/DCU")
    local_rank = int(os.environ["LOCAL_RANK"])
    torch.cuda.set_device(local_rank)
    dist.init_process_group(backend="nccl")
    return torch.device("cuda", local_rank), dist.get_rank(), dist.get_world_size()


def reduce_loss(loss: torch.Tensor) -> torch.Tensor:
    value = loss.detach().float().clone()
    if dist.is_available() and dist.is_initialized():
        dist.all_reduce(value, op=dist.ReduceOp.SUM)
        value /= dist.get_world_size()
    return value


def reduce_counts(correct: int, total: int, device: torch.device) -> tuple[int, int]:
    counts = torch.tensor([correct, total], dtype=torch.float64, device=device)
    if dist.is_available() and dist.is_initialized():
        dist.all_reduce(counts, op=dist.ReduceOp.SUM)
    return int(counts[0].item()), int(counts[1].item())


def save_attack_checkpoint(
    path: Path,
    *,
    config: WntAttackConfig,
    model: nn.Module,
    head: AngularMarginHead,
    optimizer: torch.optim.Optimizer,
    scheduler: torch.optim.lr_scheduler._LRScheduler,
    epoch: int,
    step: int,
    speakers: list[str],
) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    torch.save(
        {
            "config": asdict(config),
            "model": model.state_dict(),
            "head": head.state_dict(),
            "optimizer": optimizer.state_dict(),
            "scheduler": scheduler.state_dict(),
            "epoch": epoch,
            "step": step,
            "speakers": speakers,
        },
        temporary,
    )
    os.replace(temporary, path)


def export_finetuned_model(
    model: nn.Module,
    *,
    base_model: Path,
    destination: Path,
) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    model.save_pretrained(destination, safe_serialization=True)
    for name in ("spk_embeddings.py", "LICENSE.txt"):
        source = base_model / name
        if source.is_file():
            shutil.copy2(source, destination / name)


def freeze_wavlm_trunk(model: nn.Module) -> tuple[int, int]:
    """Freeze WavLM while leaving the W-PRO projection trainable."""
    wavlm = getattr(model, "wavlm", None)
    top_layers = getattr(model, "top_layers", None)
    if wavlm is None or top_layers is None:
        raise ValueError("W-PRO model must expose wavlm and top_layers modules")
    frozen = 0
    trainable = 0
    for parameter in wavlm.parameters():
        parameter.requires_grad_(False)
        frozen += parameter.numel()
    for parameter in top_layers.parameters():
        parameter.requires_grad_(True)
        trainable += parameter.numel()
    return frozen, trainable


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Fine-tune the 250-D W-NT/W-PRO attacker on anonymised LS360."
        )
    )
    parser.add_argument("--train-data-dir", required=True)
    parser.add_argument("--base-model", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--expected-utterances", type=int, default=104_014)
    parser.add_argument("--expected-speakers", type=int, default=921)
    parser.add_argument("--segment-seconds", type=float, default=3.0)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--lr", type=float, default=1e-4)
    parser.add_argument("--head-lr", type=float, default=1e-4)
    parser.add_argument("--weight-decay", type=float, default=2e-6)
    parser.add_argument("--gradient-clip", type=float, default=5.0)
    parser.add_argument("--aam-margin", type=float, default=0.2)
    parser.add_argument("--aam-scale", type=float, default=30.0)
    parser.add_argument(
        "--freeze-wavlm",
        action="store_true",
        help="Freeze the WavLM trunk and train only W-PRO top layers and AAM head.",
    )
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--max-hours", type=float, default=24.0)
    parser.add_argument("--checkpoint-interval", type=int, default=500)
    parser.add_argument("--seed", type=int, default=20261102)
    parser.add_argument("--device", default="cuda")
    parser.add_argument("--bf16", action="store_true")
    parser.add_argument(
        "--reset-scheduler",
        action="store_true",
        help=(
            "On resume, keep model/head/optimizer state but rebuild the "
            "cosine schedule for the new --epochs budget."
        ),
    )
    return parser.parse_args()


def main() -> int:
    from n019.models import load_wpro

    args = parse_args()
    if args.segment_seconds <= 0.0:
        raise ValueError("--segment-seconds must be positive")
    if args.epochs <= 0 or args.batch_size <= 0:
        raise ValueError("Epochs and batch size must be positive")
    if args.lr <= 0.0 or args.head_lr <= 0.0:
        raise ValueError("Learning rates must be positive")
    if args.max_hours <= 0.0:
        raise ValueError("--max-hours must be positive")
    torch.manual_seed(args.seed)
    np.random.seed(args.seed)
    random.seed(args.seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(args.seed)

    data_dir = Path(args.train_data_dir).resolve()
    base_model = Path(args.base_model).resolve()
    out = Path(args.out).resolve()
    rows, speakers = load_kaldi_rows(data_dir)
    if len(rows) != args.expected_utterances:
        raise ValueError(
            f"Expected {args.expected_utterances} utterances, got {len(rows)}"
        )
    if len(speakers) != args.expected_speakers:
        raise ValueError(
            f"Expected {args.expected_speakers} speakers, got {len(speakers)}"
        )
    counts = np.bincount(
        [int(row["speaker_index"]) for row in rows],
        minlength=len(speakers),
    )
    if int(counts.min()) == 0:
        raise ValueError("At least one speaker has no training utterance")

    out.mkdir(parents=True, exist_ok=True)
    last_checkpoint = out / "last.pt"
    model_dir = out / "model"
    config = WntAttackConfig(
        base_model=str(base_model),
        train_data_dir=str(data_dir),
        output_dir=str(out),
        expected_utterances=args.expected_utterances,
        expected_speakers=args.expected_speakers,
        segment_seconds=args.segment_seconds,
        batch_size=args.batch_size,
        epochs=args.epochs,
        learning_rate=args.lr,
        head_learning_rate=args.head_lr,
        weight_decay=args.weight_decay,
        gradient_clip=args.gradient_clip,
        aam_margin=args.aam_margin,
        aam_scale=args.aam_scale,
        freeze_wavlm=args.freeze_wavlm,
        workers=args.workers,
        max_hours=args.max_hours,
        checkpoint_interval=args.checkpoint_interval,
        seed=args.seed,
        bf16=args.bf16,
    )
    segment_samples = int(round(args.segment_seconds * SAMPLE_RATE))
    dataset = KaldiAttackDataset(
        rows,
        samples=segment_samples,
        max_samples=config.max_samples,
        seed=args.seed,
    )
    device, rank, world_size = setup_distributed(args.device)
    is_main = rank == 0
    sampler = (
        DistributedSampler(
            dataset,
            num_replicas=world_size,
            rank=rank,
            shuffle=True,
            seed=config.seed,
            drop_last=True,
        )
        if world_size > 1
        else None
    )
    loader = DataLoader(
        dataset,
        batch_size=args.batch_size,
        shuffle=sampler is None,
        sampler=sampler,
        num_workers=args.workers,
        pin_memory=torch.cuda.is_available(),
        drop_last=True,
        persistent_workers=args.workers > 0,
    )
    if len(loader) == 0:
        raise ValueError("Training loader has no batches")

    model = load_wpro(base_model, device)
    model.train()
    frozen_wavlm_parameters = 0
    trainable_projection_parameters = 0
    if config.freeze_wavlm:
        frozen_wavlm_parameters, trainable_projection_parameters = (
            freeze_wavlm_trunk(model)
        )
        model.wavlm.eval()
    head = AngularMarginHead(
        250,
        len(speakers),
        margin=config.aam_margin,
        scale=config.aam_scale,
    ).to(device)
    classifier = WntClassifier(model, head)
    optimizer = torch.optim.AdamW(
        [
            {
                "params": [
                    parameter
                    for parameter in model.parameters()
                    if parameter.requires_grad
                ],
                "lr": config.learning_rate,
            },
            {
                "params": list(head.parameters()),
                "lr": config.head_learning_rate,
            },
        ],
        weight_decay=config.weight_decay,
    )
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
        optimizer,
        T_max=config.epochs,
    )
    start_epoch = 0
    global_step = 0
    if last_checkpoint.is_file():
        checkpoint = torch.load(
            last_checkpoint,
            map_location=device,
            weights_only=False,
        )
        saved = checkpoint.get("config", {})
        for key in (
            "base_model",
            "train_data_dir",
            "expected_utterances",
            "expected_speakers",
        ):
            if saved.get(key) != asdict(config).get(key):
                raise ValueError(
                    f"Checkpoint {key} does not match current arguments"
                )
        if checkpoint.get("speakers") != speakers:
            raise ValueError("Checkpoint speaker order does not match dataset")
        model.load_state_dict(checkpoint["model"])
        head.load_state_dict(checkpoint["head"])
        optimizer.load_state_dict(checkpoint["optimizer"])
        if args.reset_scheduler:
            for parameter_group, target_lr in zip(
                optimizer.param_groups,
                (config.learning_rate, config.head_learning_rate),
                strict=True,
            ):
                parameter_group["lr"] = target_lr
        else:
            scheduler.load_state_dict(checkpoint["scheduler"])
        start_epoch = int(checkpoint["epoch"]) + 1
        global_step = int(checkpoint["step"])

    if world_size > 1:
        classifier = DistributedDataParallel(
            classifier,
            device_ids=[device.index],
            output_device=device.index,
        )
    classifier_module = (
        classifier.module if world_size > 1 else classifier
    )
    if is_main:
        write_json(
            out / "meta.json",
            {
                "config": asdict(config),
                "utterances": len(rows),
                "speakers": len(speakers),
                "speaker_counts_min": int(counts.min()),
                "speaker_counts_max": int(counts.max()),
                "head_parameters": sum(
                    parameter.numel() for parameter in head.parameters()
                ),
                "model_parameters": sum(
                    parameter.numel() for parameter in model.parameters()
                ),
                "frozen_wavlm_parameters": frozen_wavlm_parameters,
                "trainable_projection_parameters": (
                    trainable_projection_parameters
                ),
                "world_size": world_size,
                "per_rank_batch_size": args.batch_size,
                "effective_batch_size": args.batch_size * world_size,
                "input_sha256": {
                    "wav_scp": sha256_file(data_dir / "wav.scp"),
                    "utt2spk": sha256_file(data_dir / "utt2spk"),
                    "base_model": sha256_file(base_model / "model.safetensors"),
                },
            },
        )
    log_path = out / "training_log.jsonl"
    log_handle = log_path.open("a", encoding="utf-8") if is_main else None
    started = time.time()
    last_completed_epoch = start_epoch - 1
    for epoch in range(start_epoch, config.epochs):
        if sampler is not None:
            sampler.set_epoch(epoch)
        dataset.set_epoch(epoch)
        classifier.train()
        if config.freeze_wavlm:
            classifier_module.model.wavlm.eval()
        running_loss = 0.0
        running_correct = 0
        running_items = 0
        for waveforms, labels in loader:
            waveforms = waveforms.to(device, non_blocking=True)
            labels = labels.to(device, non_blocking=True)
            optimizer.zero_grad(set_to_none=True)
            with torch.autocast(
                device_type="cuda",
                dtype=torch.bfloat16,
                enabled=config.bf16 and device.type == "cuda",
            ):
                logits = classifier(waveforms, labels)
                loss = F.cross_entropy(logits.float(), labels)
            if not bool(torch.isfinite(loss)):
                raise RuntimeError(
                    f"Non-finite W-NT attack loss at epoch {epoch + 1}"
                )
            loss.backward()
            torch.nn.utils.clip_grad_norm_(
                classifier.parameters(),
                config.gradient_clip,
            )
            optimizer.step()
            global_step += 1
            reduced_loss = reduce_loss(loss)
            correct, total = reduce_counts(
                int(
                    (logits.argmax(dim=1) == labels).sum().item()
                ),
                labels.numel(),
                device,
            )
            running_items += total
            running_loss += float(reduced_loss) * total
            running_correct += correct
            if is_main and (
                global_step == 1
                or global_step % 20 == 0
                or (time.time() - started) / 3600 >= config.max_hours
            ):
                row = {
                    "epoch": epoch + 1,
                    "step": global_step,
                    "loss": running_loss / max(1, running_items),
                    "accuracy": running_correct / max(1, running_items),
                    "elapsed_hours": (time.time() - started) / 3600,
                    "lr": optimizer.param_groups[0]["lr"],
                    "head_lr": optimizer.param_groups[1]["lr"],
                    "world_size": world_size,
                    "per_rank_batch_size": args.batch_size,
                }
                print(json.dumps(row), flush=True)
                assert log_handle is not None
                log_handle.write(json.dumps(row) + "\n")
                log_handle.flush()
            if global_step % config.checkpoint_interval == 0:
                if world_size > 1:
                    dist.barrier()
                if is_main:
                    save_attack_checkpoint(
                        last_checkpoint,
                        config=config,
                        model=classifier_module.model,
                        head=classifier_module.head,
                        optimizer=optimizer,
                        scheduler=scheduler,
                        epoch=epoch,
                        step=global_step,
                        speakers=speakers,
                    )
                if world_size > 1:
                    dist.barrier()
            if (time.time() - started) / 3600 >= config.max_hours:
                break
        scheduler.step()
        if world_size > 1:
            dist.barrier()
        if is_main:
            save_attack_checkpoint(
                last_checkpoint,
                config=config,
                model=classifier_module.model,
                head=classifier_module.head,
                optimizer=optimizer,
                scheduler=scheduler,
                epoch=epoch,
                step=global_step,
                speakers=speakers,
            )
            export_finetuned_model(
                classifier_module.model,
                base_model=base_model,
                destination=model_dir,
            )
            epoch_row = {
                "epoch": epoch + 1,
                "step": global_step,
                "epoch_loss": running_loss / max(1, running_items),
                "epoch_accuracy": running_correct / max(1, running_items),
                "elapsed_hours": (time.time() - started) / 3600,
                "world_size": world_size,
            }
            print(json.dumps(epoch_row), flush=True)
            assert log_handle is not None
            log_handle.write(json.dumps(epoch_row) + "\n")
            log_handle.flush()
        last_completed_epoch = epoch
        if (time.time() - started) / 3600 >= config.max_hours:
            break
    if log_handle is not None:
        log_handle.close()
    if world_size > 1:
        dist.barrier()
    if is_main:
        write_json(
            out / "export.json",
            {
                "model_dir": str(model_dir),
                "last_checkpoint": str(last_checkpoint),
                "last_checkpoint_sha256": sha256_file(last_checkpoint),
                "model_safetensors_sha256": sha256_file(
                    model_dir / "model.safetensors"
                ),
                "step": global_step,
                "epoch": min(last_completed_epoch + 1, config.epochs),
                "world_size": world_size,
            },
        )
    if dist.is_available() and dist.is_initialized():
        dist.destroy_process_group()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
