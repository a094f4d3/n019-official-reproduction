"""Speaker-conditioned unit-duration predictor and training pipeline."""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import time
from dataclasses import asdict, dataclass
from functools import partial
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from torch import nn
from torch.nn.utils.rnn import pad_sequence
from torch.utils.data import DataLoader, Dataset

from n019.audio import collapse_consecutive
from n019.manifest import (
    iter_jsonl,
    sha256_file,
    speaker_id,
    utterance_id,
    write_json,
)


@dataclass(frozen=True)
class DurationModelConfig:
    vocabulary_size: int = 201
    padding_unit_id: int = 200
    unit_embedding_dim: int = 32
    speaker_dim: int = 250
    speaker_projection_dim: int | None = 32
    hidden_dim: int = 128
    num_layers: int = 7
    kernel_size: int = 3
    masking_rate: float = 0.2
    activation_slope: float = 0.01
    window_size: int = 4
    window_stride: int = 4
    window_loss_weight: float = 0.5
    output_activation: str = "linear"
    normalize_durations: bool = True


class UnitDurationPredictor(nn.Module):
    """DISSC length predictor with N019 speaker conditioning.

    Reference [17] uses seven 128-channel Conv1d layers, BatchNorm, LeakyReLU,
    and a linear output. N019 replaces the learned speaker-ID lookup with a
    projection of an NT or ECAPA embedding. The unconditional DU-pred variant
    removes that projection entirely.
    """

    def __init__(self, config: DurationModelConfig) -> None:
        super().__init__()
        if config.kernel_size % 2 == 0:
            raise ValueError("kernel_size must be odd")
        if config.num_layers < 1:
            raise ValueError("num_layers must be positive")
        if not 0.0 <= config.masking_rate < 1.0:
            raise ValueError("masking_rate must be in [0, 1)")
        self.config = config
        self.unit_embedding = nn.Embedding(
            config.vocabulary_size,
            config.unit_embedding_dim,
            padding_idx=config.padding_unit_id,
        )
        input_dim = config.unit_embedding_dim
        if config.speaker_dim > 0:
            projected_dim = (
                config.speaker_projection_dim
                if config.speaker_projection_dim is not None
                else config.unit_embedding_dim
            )
            if projected_dim <= 0:
                raise ValueError("speaker_projection_dim must be positive")
            self.speaker_projection = nn.Linear(
                config.speaker_dim,
                projected_dim,
            )
            input_dim += projected_dim
        else:
            self.speaker_projection = None
        padding = (config.kernel_size - 1) // 2
        self.convs = nn.ModuleList()
        self.norms = nn.ModuleList()
        for index in range(config.num_layers):
            self.convs.append(
                nn.Conv1d(
                    input_dim if index == 0 else config.hidden_dim,
                    config.hidden_dim,
                    config.kernel_size,
                    padding=padding,
                )
            )
            self.norms.append(nn.BatchNorm1d(config.hidden_dim))
        self.activation = nn.LeakyReLU(config.activation_slope)
        self.output = nn.Conv1d(
            config.hidden_dim,
            1,
            config.kernel_size,
            padding=padding,
        )
        self.register_buffer("duration_mean", torch.tensor(0.0))
        self.register_buffer("duration_std", torch.tensor(1.0))

    def set_duration_statistics(self, mean: float, std: float) -> None:
        if not math.isfinite(mean) or not math.isfinite(std):
            raise ValueError("duration statistics must be finite")
        if std <= 0.0:
            raise ValueError("duration standard deviation must be positive")
        self.duration_mean.fill_(float(mean))
        self.duration_std.fill_(float(std))

    def forward(
        self,
        units: torch.Tensor,
        speaker_embedding: torch.Tensor | None = None,
    ) -> torch.Tensor:
        if units.ndim != 2:
            raise ValueError("units must have shape [batch, length]")
        valid = (units != self.config.padding_unit_id).unsqueeze(-1)
        x = self.unit_embedding(units) * valid.to(self.unit_embedding.weight.dtype)
        if self.training and self.config.masking_rate > 0.0:
            random_mask = (
                torch.rand(units.shape, device=units.device)
                < self.config.masking_rate
            )
            x = x.masked_fill(
                (random_mask & valid.squeeze(-1)).unsqueeze(-1),
                0.0,
            )
        if self.config.speaker_dim > 0:
            if speaker_embedding is None:
                raise ValueError("This predictor requires speaker embeddings")
            if speaker_embedding.ndim != 2:
                raise ValueError("speaker_embedding must be [batch, dim]")
            if speaker_embedding.shape != (
                units.shape[0],
                self.config.speaker_dim,
            ):
                raise ValueError(
                    f"Expected speaker embeddings with shape "
                    f"{(units.shape[0], self.config.speaker_dim)}, "
                    f"got {tuple(speaker_embedding.shape)}"
                )
            assert self.speaker_projection is not None
            speaker = self.speaker_projection(speaker_embedding.float()).unsqueeze(1)
            speaker = speaker.expand(-1, units.shape[1], -1)
            speaker = speaker * valid.to(speaker.dtype)
            x = torch.cat([x, speaker], dim=-1)
        elif speaker_embedding is not None:
            raise ValueError("Unconditional predictor received speaker embeddings")

        hidden = x.transpose(1, 2)
        for conv, norm in zip(self.convs, self.norms):
            hidden = self.activation(norm(conv(hidden)))
            hidden = hidden * valid.transpose(1, 2).to(hidden.dtype)
        raw = self.output(hidden).squeeze(1)
        if self.config.output_activation == "softplus":
            raw = F.softplus(raw)
        elif self.config.output_activation == "relu":
            raw = F.relu(raw)
        elif self.config.output_activation != "linear":
            raise ValueError(
                "Unsupported duration output activation: "
                f"{self.config.output_activation}"
            )
        if self.config.normalize_durations:
            return raw * self.duration_std + self.duration_mean
        return raw


def duration_objective(
    prediction: torch.Tensor,
    target: torch.Tensor,
    mask: torch.Tensor,
    *,
    window_size: int = 4,
    window_stride: int = 4,
    window_weight: float = 0.5,
) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
    if prediction.shape != target.shape or prediction.shape != mask.shape:
        raise ValueError("prediction, target, and mask must have equal shapes")
    if not bool(mask.any()):
        raise ValueError("Duration batch has no valid frames")
    valid_frames = mask.sum().to(prediction.dtype)
    point = (
        (prediction - target).square() * mask.to(prediction.dtype)
    ).sum() / valid_frames
    if prediction.shape[1] < window_size:
        zero = prediction.sum() * 0.0
        return point + window_weight * zero, point, zero
    if window_stride <= 0:
        raise ValueError("window_stride must be positive")
    pred_window = prediction.unfold(
        1,
        window_size,
        window_stride,
    ).sum(dim=-1)
    target_window = target.unfold(
        1,
        window_size,
        window_stride,
    ).sum(dim=-1)
    window_mask = mask.unfold(
        1,
        window_size,
        window_stride,
    ).all(dim=-1)
    if bool(window_mask.any()):
        window = (
            (
                pred_window[window_mask]
                - target_window[window_mask]
            ).square().sum()
            / valid_frames
        )
    else:
        window = prediction.sum() * 0.0
    return point + window_weight * window, point, window


class DurationDataset(Dataset):
    def __init__(
        self,
        records_path: str | Path,
        embeddings_path: str | Path | None,
        *,
        speakers: set[str] | None = None,
        embedding_level: str = "speaker",
        padding_unit_id: int = 200,
    ) -> None:
        self.records = [
            row
            for row in iter_jsonl(records_path)
            if speakers is None or speaker_id(row) in speakers
        ]
        if not self.records:
            raise ValueError("No duration records selected")
        self.embeddings = {}
        if embeddings_path is not None:
            archive = np.load(embeddings_path, allow_pickle=False)
            self.embeddings = {
                key: torch.from_numpy(archive[key].astype(np.float32))
                for key in archive.files
            }
            archive.close()
        if self.embeddings:
            dimensions = {
                int(value.numel())
                for value in self.embeddings.values()
            }
            if len(dimensions) != 1:
                raise ValueError(
                    f"Mixed embedding dimensions in {embeddings_path}: "
                    f"{dimensions}"
                )
            self.embedding_dim = dimensions.pop()
        else:
            self.embedding_dim = 0
        self.embedding_level = embedding_level
        self.padding_unit_id = padding_unit_id

    def __len__(self) -> int:
        return len(self.records)

    def __getitem__(self, index: int):
        row = self.records[index]
        codes = np.load(row["codes_path"]).astype(np.int64, copy=False)
        if codes.size == 0:
            raise ValueError(f"Empty code sequence: {row['codes_path']}")
        if int(codes.min()) < 0 or int(codes.max()) >= self.padding_unit_id:
            raise ValueError(f"Invalid unit IDs in {row['codes_path']}")
        units, durations = collapse_consecutive(torch.from_numpy(codes).long())
        if units.numel() == 0:
            raise ValueError(f"Empty code sequence: {row['codes_path']}")
        if not self.embeddings:
            speaker = None
        else:
            key = (
                speaker_id(row)
                if self.embedding_level == "speaker"
                else utterance_id(row)
            )
            if key not in self.embeddings:
                raise KeyError(f"Speaker embedding missing key: {key}")
            speaker = self.embeddings[key]
        return units, durations.float(), speaker

    def duration_statistics(self) -> tuple[float, float]:
        count = 0
        total = 0.0
        total_squared = 0.0
        for row in self.records:
            codes = np.load(row["codes_path"]).astype(np.int64, copy=False)
            if codes.size == 0:
                raise ValueError(f"Empty code sequence: {row['codes_path']}")
            if int(codes.min()) < 0 or int(codes.max()) >= self.padding_unit_id:
                raise ValueError(f"Invalid unit IDs in {row['codes_path']}")
            _, durations = collapse_consecutive(torch.from_numpy(codes).long())
            values = durations.to(torch.float64)
            count += int(values.numel())
            total += float(values.sum())
            total_squared += float(values.square().sum())
        if count == 0:
            raise ValueError("No unit durations available")
        mean = total / count
        variance = max(0.0, total_squared / count - mean * mean)
        return mean, max(math.sqrt(variance), 1e-6)


def collate_duration(batch, *, padding_unit_id: int):
    units, durations, speakers = zip(*batch)
    speaker_tensor = (
        torch.stack(speakers)
        if speakers[0] is not None
        else None
    )
    return (
        pad_sequence(
            units,
            batch_first=True,
            padding_value=padding_unit_id,
        ),
        pad_sequence(durations, batch_first=True, padding_value=0.0),
        speaker_tensor,
    )


def split_speakers(
    records_path: str | Path,
    *,
    seed: int,
    validation_fraction: float,
) -> tuple[set[str], set[str]]:
    if not 0.0 < validation_fraction < 1.0:
        raise ValueError("validation_fraction must be in (0, 1)")
    speakers = sorted({speaker_id(row) for row in iter_jsonl(records_path)})
    if len(speakers) < 2:
        raise ValueError("At least two speakers are required")
    rng = random.Random(seed)
    rng.shuffle(speakers)
    dev_count = max(1, round(len(speakers) * validation_fraction))
    dev_count = min(dev_count, len(speakers) - 1)
    return set(speakers[dev_count:]), set(speakers[:dev_count])


def masked_duration_metrics(
    prediction: torch.Tensor,
    target: torch.Tensor,
    mask: torch.Tensor,
) -> dict[str, float]:
    valid_prediction = prediction[mask]
    valid_target = target[mask]
    mae = torch.mean(torch.abs(valid_prediction - valid_target))
    rmse = torch.sqrt(torch.mean((valid_prediction - valid_target) ** 2))
    total = 0.0
    total_error = 0.0
    for index in range(prediction.shape[0]):
        length = int(mask[index].sum())
        pred_sum = prediction[index, :length].sum()
        target_sum = target[index, :length].sum()
        total += float(target_sum)
        total_error += abs(float(pred_sum - target_sum))
    return {
        "mae": float(mae),
        "rmse": float(rmse),
        "total_duration": total,
        "total_duration_abs_error": total_error,
        "total_duration_relative_error": total_error / max(1e-8, total),
        "frames": int(mask.sum()),
    }


def save_duration_checkpoint(
    path: str | Path,
    model: UnitDurationPredictor,
    optimizer: torch.optim.Optimizer,
    *,
    epoch: int,
    best_dev: float | None,
    training_config: dict,
) -> None:
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    torch.save(
        {
            "model": model.state_dict(),
            "optimizer": optimizer.state_dict(),
            "model_config": asdict(model.config),
            "training_config": training_config,
            "epoch": epoch,
            "best_dev": best_dev,
        },
        temporary,
    )
    os.replace(temporary, destination)


def load_duration_checkpoint(
    path: str | Path,
    *,
    device: torch.device,
) -> tuple[UnitDurationPredictor, dict]:
    checkpoint = torch.load(path, map_location=device, weights_only=False)
    config = DurationModelConfig(**checkpoint["model_config"])
    model = UnitDurationPredictor(config).to(device)
    model.load_state_dict(checkpoint["model"])
    model.eval()
    return model, checkpoint


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train the N019 speaker-conditioned unit duration predictor."
    )
    parser.add_argument("--records", required=True)
    parser.add_argument("--embeddings", default=None)
    parser.add_argument("--out", required=True)
    parser.add_argument("--embedding-level", choices=["speaker", "utterance"], default="speaker")
    parser.add_argument(
        "--embedding-kind",
        choices=["nt", "ecapa", "none"],
        default=None,
    )
    parser.add_argument("--speaker-dim", type=int, choices=[0, 192, 250], default=250)
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--lr", type=float, default=3e-4)
    parser.add_argument("--weight-decay", type=float, default=0.0)
    parser.add_argument("--validation-fraction", type=float, default=0.0)
    parser.add_argument("--window-size", type=int, default=4)
    parser.add_argument("--window-stride", type=int, default=4)
    parser.add_argument("--window-weight", type=float, default=0.5)
    parser.add_argument("--masking-rate", type=float, default=0.2)
    parser.add_argument("--hidden-dim", type=int, default=128)
    parser.add_argument("--num-layers", type=int, default=7)
    parser.add_argument(
        "--output-activation",
        choices=["linear", "softplus", "relu"],
        default="linear",
    )
    parser.add_argument("--gradient-clip", type=float, default=1.0)
    parser.add_argument(
        "--checkpoint-metric",
        choices=["mae", "total_duration_relative_error"],
        default="total_duration_relative_error",
        help=(
            "Dev metric for best-checkpoint selection. Total-duration error "
            "matches the inference role of the predictor more closely than "
            "unit-level MAE."
        ),
    )
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--seed", type=int, default=20261102)
    parser.add_argument("--device", default="cuda")
    return parser.parse_args()


def output_is_pristine(out: Path) -> bool:
    """Allow the wrapper's launch metadata, but no training artifacts."""
    if not out.exists():
        return True
    return {path.name for path in out.iterdir()} <= {"launch.txt"}


def main() -> int:
    args = parse_args()
    if args.epochs <= 0:
        raise ValueError("--epochs must be positive")
    if args.batch_size <= 0:
        raise ValueError("--batch-size must be positive")
    if args.num_layers <= 0 or args.hidden_dim <= 0:
        raise ValueError("--num-layers and --hidden-dim must be positive")
    if args.window_size <= 0 or args.window_stride <= 0:
        raise ValueError("window size and stride must be positive")
    if args.window_weight < 0.0:
        raise ValueError("--window-weight must be non-negative")
    if not 0.0 <= args.validation_fraction < 1.0:
        raise ValueError("--validation-fraction must be in [0, 1)")
    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA/DCU requested but unavailable")
    out = Path(args.out)
    last_checkpoint = out / "last.pt"
    if out.exists() and not output_is_pristine(out) and not args.resume:
        raise FileExistsError(
            f"Output directory is not empty: {out}; pass --resume or choose a new run"
        )
    if args.resume and not last_checkpoint.is_file():
        raise FileNotFoundError(last_checkpoint)
    out.mkdir(parents=True, exist_ok=True)
    if args.speaker_dim > 0 and not args.embeddings:
        raise ValueError("--embeddings is required for conditioned predictors")
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(args.seed)
    device = torch.device(args.device)
    if args.speaker_dim == 0:
        inferred_kind = "none"
    elif args.speaker_dim == 250:
        inferred_kind = "nt"
    else:
        inferred_kind = "ecapa"
    embedding_kind = args.embedding_kind or inferred_kind
    expected_kind = {
        0: "none",
        192: "ecapa",
        250: "nt",
    }[args.speaker_dim]
    if embedding_kind != expected_kind:
        raise ValueError(
            f"--embedding-kind {embedding_kind} conflicts with "
            f"--speaker-dim {args.speaker_dim}"
        )
    if args.validation_fraction == 0.0:
        train_speakers = None
        dev_speakers: set[str] = set()
    else:
        train_speakers, dev_speakers = split_speakers(
            args.records,
            seed=args.seed,
            validation_fraction=args.validation_fraction,
        )
    train_dataset = DurationDataset(
        args.records,
        args.embeddings if args.speaker_dim > 0 else None,
        speakers=train_speakers,
        embedding_level=args.embedding_level,
        padding_unit_id=DurationModelConfig().padding_unit_id,
    )
    if args.speaker_dim > 0 and train_dataset.embedding_dim != args.speaker_dim:
        raise ValueError(
            f"Embedding dimension {train_dataset.embedding_dim} does not match "
            f"--speaker-dim {args.speaker_dim}"
        )
    dev_dataset = (
        DurationDataset(
            args.records,
            args.embeddings if args.speaker_dim > 0 else None,
            speakers=dev_speakers,
            embedding_level=args.embedding_level,
            padding_unit_id=DurationModelConfig().padding_unit_id,
        )
        if dev_speakers
        else None
    )
    collate = partial(
        collate_duration,
        padding_unit_id=DurationModelConfig().padding_unit_id,
    )
    train_loader = DataLoader(
        train_dataset,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=args.workers,
        collate_fn=collate,
        drop_last=len(train_dataset) >= args.batch_size,
        persistent_workers=args.workers > 0,
    )
    dev_loader = (
        DataLoader(
            dev_dataset,
            batch_size=args.batch_size,
            shuffle=False,
            num_workers=args.workers,
            collate_fn=collate,
            persistent_workers=args.workers > 0,
        )
        if dev_dataset is not None
        else None
    )
    model_config = DurationModelConfig(
        speaker_dim=args.speaker_dim,
        hidden_dim=args.hidden_dim,
        num_layers=args.num_layers,
        masking_rate=args.masking_rate,
        window_size=args.window_size,
        window_stride=args.window_stride,
        window_loss_weight=args.window_weight,
        output_activation=args.output_activation,
    )
    model = UnitDurationPredictor(model_config).to(device)
    duration_mean, duration_std = train_dataset.duration_statistics()
    model.set_duration_statistics(duration_mean, duration_std)
    optimizer = torch.optim.Adam(
        model.parameters(),
        lr=args.lr,
        weight_decay=args.weight_decay,
    )
    training_config = {
        **vars(args),
        "embedding_kind": embedding_kind,
        "duration_mean": duration_mean,
        "duration_std": duration_std,
        "best_dev_metric": args.checkpoint_metric,
    }
    best = math.inf
    best_dev_metrics: dict | None = None
    history = []
    resume_epoch = 0
    if args.resume and last_checkpoint.is_file():
        checkpoint = torch.load(
            last_checkpoint,
            map_location=device,
            weights_only=False,
        )
        if checkpoint["model_config"] != asdict(model_config):
            raise ValueError(
                "Duration checkpoint model config does not match current args"
            )
        model.load_state_dict(checkpoint["model"])
        optimizer.load_state_dict(checkpoint["optimizer"])
        resume_epoch = int(checkpoint["epoch"])
        stored_best = checkpoint.get("best_dev")
        best = math.inf if stored_best is None else float(stored_best)
    log_path = out / "training_log.jsonl"
    if log_path.is_file():
        for row in iter_jsonl(log_path):
            history.append(row)
    log_handle = log_path.open("a", encoding="utf-8")
    for epoch in range(resume_epoch, args.epochs):
        started = time.time()
        model.train()
        train_loss = 0.0
        train_point = 0.0
        train_window = 0.0
        train_frames = 0
        for units, durations, speakers in train_loader:
            units = units.to(device)
            durations = durations.to(device)
            if speakers is not None:
                speakers = speakers.to(device)
            mask = units != model_config.padding_unit_id
            prediction = model(units, speakers if args.speaker_dim else None)
            loss, point, window = duration_objective(
                prediction,
                durations,
                mask,
                window_size=args.window_size,
                window_stride=args.window_stride,
                window_weight=args.window_weight,
            )
            if not bool(torch.isfinite(loss)):
                raise RuntimeError(
                    f"Non-finite duration loss at epoch {epoch + 1}"
                )
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            if args.gradient_clip > 0:
                torch.nn.utils.clip_grad_norm_(
                    model.parameters(),
                    args.gradient_clip,
                )
            optimizer.step()
            valid_frames = int(mask.sum())
            train_loss += float(loss.detach()) * max(1, valid_frames)
            train_point += float(point.detach()) * max(1, valid_frames)
            train_window += float(window.detach()) * max(1, valid_frames)
            train_frames += valid_frames

        model.eval()
        dev_metrics = None
        if dev_loader is not None:
            dev_frames = 0
            dev_absolute_error = 0.0
            dev_squared_error = 0.0
            dev_target_total = 0.0
            dev_duration_error = 0.0
            with torch.inference_mode():
                for units, durations, speakers in dev_loader:
                    units = units.to(device)
                    durations = durations.to(device)
                    if speakers is not None:
                        speakers = speakers.to(device)
                    mask = units != model_config.padding_unit_id
                    prediction = model(
                        units,
                        speakers if args.speaker_dim else None,
                    )
                    metrics = masked_duration_metrics(
                        prediction,
                        durations,
                        mask,
                    )
                    frames = int(metrics["frames"])
                    dev_frames += frames
                    dev_absolute_error += metrics["mae"] * frames
                    dev_squared_error += (metrics["rmse"] ** 2) * frames
                    dev_target_total += metrics["total_duration"]
                    dev_duration_error += metrics["total_duration_abs_error"]
            dev_frames = max(1, dev_frames)
            dev_metrics = {
                "mae": dev_absolute_error / dev_frames,
                "rmse": math.sqrt(dev_squared_error / dev_frames),
                "total_duration_abs_error": dev_duration_error,
                "total_duration_relative_error": (
                    dev_duration_error / max(1e-8, dev_target_total)
                ),
                "frames": dev_frames,
            }
        row = {
            "epoch": epoch + 1,
            "train_loss": train_loss / max(1, train_frames),
            "train_point_mse": train_point / max(1, train_frames),
            "train_window_contribution": train_window / max(1, train_frames),
            "dev": dev_metrics,
            "elapsed_seconds": time.time() - started,
        }
        history.append(row)
        print(json.dumps(row), flush=True)
        log_handle.write(json.dumps(row) + "\n")
        log_handle.flush()
        save_duration_checkpoint(
            last_checkpoint,
            model,
            optimizer,
            epoch=epoch + 1,
            best_dev=None if math.isinf(best) else best,
            training_config=training_config,
        )
        dev_selection_value = (
            dev_metrics[args.checkpoint_metric]
            if dev_metrics is not None
            else None
        )
        if dev_selection_value is not None and dev_selection_value < best:
            best = dev_selection_value
            best_dev_metrics = dict(dev_metrics)
            save_duration_checkpoint(
                out / "best.pt",
                model,
                optimizer,
                epoch=epoch + 1,
                best_dev=best,
                training_config=training_config,
            )
    log_handle.close()
    if dev_loader is None:
        save_duration_checkpoint(
            out / "best.pt",
            model,
            optimizer,
            epoch=max(resume_epoch, args.epochs),
            best_dev=None,
            training_config=training_config,
        )
    write_json(out / "history.json", {"epochs": history})
    write_json(
        out / "meta.json",
        {
            "args": training_config,
            "model_config": asdict(model_config),
            "train_records": len(train_dataset),
            "dev_records": len(dev_dataset) if dev_dataset is not None else 0,
            "train_speakers": (
                sorted(train_speakers)
                if train_speakers is not None
                else sorted(
                    {
                        speaker_id(row)
                        for row in iter_jsonl(args.records)
                    }
                )
            ),
            "dev_speakers": sorted(dev_speakers),
            "checkpoint_metric": args.checkpoint_metric,
            "best_dev_metric_value": None if math.isinf(best) else best,
            "best_dev_metrics": best_dev_metrics,
            "best_dev_mae": (
                best_dev_metrics["mae"]
                if best_dev_metrics is not None
                else None
            ),
            "embedding_kind": embedding_kind,
            "duration_mean": duration_mean,
            "duration_std": duration_std,
            "input_sha256": {
                "records": sha256_file(args.records),
                **(
                    {"embeddings": sha256_file(args.embeddings)}
                    if args.embeddings
                    else {}
                ),
            },
        },
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
