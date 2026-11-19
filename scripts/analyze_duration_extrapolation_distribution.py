"""Measure duration-predictor distortion before choosing a cap screen."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch
from torch.nn.utils.rnn import pad_sequence

from n019.audio import (
    collapse_consecutive,
    sanitize_predicted_durations,
)
from n019.duration import load_duration_checkpoint
from n019.manifest import iter_jsonl


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--unit-records", required=True)
    parser.add_argument("--duration-model", required=True)
    parser.add_argument("--strength", type=float, default=0.5)
    parser.add_argument("--batch-size", type=int, default=128)
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--out", required=True)
    return parser.parse_args()


def quantiles(values: np.ndarray) -> dict[str, float]:
    if values.size == 0:
        raise ValueError("Cannot summarize an empty array")
    points = (0.0, 0.5, 0.9, 0.95, 0.99, 1.0)
    samples = np.quantile(values, points)
    return {
        f"p{int(point * 100):02d}": float(value)
        for point, value in zip(points, samples)
    }


def main() -> int:
    args = parse_args()
    if args.strength < 0.0:
        raise ValueError("strength must be non-negative")
    if args.batch_size <= 0:
        raise ValueError("batch-size must be positive")
    device = torch.device(args.device)
    model, checkpoint = load_duration_checkpoint(
        args.duration_model,
        device=device,
    )
    if checkpoint.get("training_config", {}).get("embedding_kind") != "none":
        raise ValueError("This analysis expects the unconditional duration model")

    sequences: list[tuple[torch.Tensor, torch.Tensor]] = []
    for row in iter_jsonl(args.unit_records):
        codes = np.load(row["codes_path"]).astype(np.int64, copy=False)
        units, durations = collapse_consecutive(torch.from_numpy(codes).long())
        if units.numel() == 0:
            raise ValueError(f"Empty unit sequence: {row['codes_path']}")
        sequences.append((units, durations.float()))

    predicted_values: list[np.ndarray] = []
    original_values: list[np.ndarray] = []
    with torch.no_grad():
        for start in range(0, len(sequences), args.batch_size):
            batch = sequences[start : start + args.batch_size]
            lengths = torch.tensor(
                [units.numel() for units, _ in batch],
                dtype=torch.long,
            )
            units = pad_sequence(
                [item[0] for item in batch],
                batch_first=True,
                padding_value=200,
            ).to(device)
            predicted = model(units)
            for index, length in enumerate(lengths.tolist()):
                values, _ = sanitize_predicted_durations(
                    predicted[index, :length].cpu()
                )
                predicted_values.append(values.numpy().astype(np.float64))
                original_values.append(
                    batch[index][1].numpy().astype(np.float64)
                )

    predicted = np.concatenate(predicted_values)
    original = np.concatenate(original_values)
    if predicted.shape != original.shape:
        raise ValueError("Predicted and original arrays differ in shape")
    delta = predicted - original
    base_adjusted = predicted + args.strength * delta
    ratio = np.divide(
        np.abs(delta),
        np.maximum(predicted, 1e-6),
        out=np.zeros_like(delta),
        where=predicted > 1e-6,
    )

    cap_results: dict[str, dict[str, float | int]] = {}
    for cap in (0.25, 0.5, 0.75, 1.0, 1.5, 2.0):
        relative = delta / np.maximum(predicted, cap)
        soft_delta = cap * np.tanh(relative)
        adjusted = predicted + soft_delta
        pre_total = float(np.maximum(predicted, 0.0).sum())
        adjusted = np.maximum(adjusted, 0.0)
        adjusted_total = float(adjusted.sum())
        if adjusted_total <= 0.0:
            raise ValueError("Adjusted duration total must be positive")
        adjusted *= pre_total / adjusted_total
        post_delta = adjusted - predicted
        cap_results[str(cap)] = {
            "post_abs_delta_mean_frames": float(np.abs(post_delta).mean()),
            "post_abs_delta_p95_frames": float(np.quantile(np.abs(post_delta), 0.95)),
            "post_abs_delta_max_frames": float(np.abs(post_delta).max()),
            "post_abs_relative_delta_mean": float(
                np.mean(np.abs(post_delta) / np.maximum(predicted, 1e-6))
            ),
            "units_changed_fraction": float(np.mean(np.abs(post_delta) > 0.05)),
        }

    result = {
        "unit_records": args.unit_records,
        "duration_model": args.duration_model,
        "utterances": len(sequences),
        "units": int(predicted.size),
        "strength": args.strength,
        "predicted_frames": quantiles(predicted),
        "original_frames": quantiles(original),
        "signed_delta_frames": quantiles(delta),
        "absolute_delta_frames": quantiles(np.abs(delta)),
        "absolute_relative_delta": quantiles(ratio),
        "base_extrapolated_absolute_delta_frames": quantiles(
            np.abs(base_adjusted - predicted)
        ),
        "base_extrapolated_absolute_relative_delta": quantiles(
            np.abs(base_adjusted - predicted)
            / np.maximum(predicted, 1e-6)
        ),
        "negative_predicted_units": int((predicted < 0.0).sum()),
        "soft_caps": cap_results,
    }
    destination = Path(args.out)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
