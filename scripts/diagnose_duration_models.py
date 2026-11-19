"""Compare two duration checkpoints on one unit-record manifest."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
import torch

from n019.audio import (
    collapse_consecutive,
    round_durations_with_residual,
    sanitize_predicted_durations,
)
from n019.duration import load_duration_checkpoint
from n019.manifest import iter_jsonl, sha256_file


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--records", required=True)
    parser.add_argument("--baseline-model", required=True)
    parser.add_argument("--candidate-model", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--limit", type=int, default=0)
    return parser.parse_args()


def predict(
    model: torch.nn.Module,
    units: torch.Tensor,
    device: torch.device,
) -> torch.Tensor:
    with torch.inference_mode():
        values = model(units.unsqueeze(0).to(device), None)[0].cpu()
    values, _ = sanitize_predicted_durations(values)
    return round_durations_with_residual(values, minimum_one=True).float()


def main() -> int:
    args = parse_args()
    if args.limit < 0:
        raise ValueError("--limit must be non-negative")
    device = torch.device(args.device)
    baseline, _ = load_duration_checkpoint(args.baseline_model, device=device)
    candidate, _ = load_duration_checkpoint(args.candidate_model, device=device)
    baseline.eval()
    candidate.eval()

    rows = list(iter_jsonl(args.records))
    if args.limit:
        rows = rows[: args.limit]
    if not rows:
        raise ValueError("No duration records selected")

    original_total = 0.0
    baseline_total = 0.0
    candidate_total = 0.0
    baseline_rel_errors: list[float] = []
    candidate_rel_errors: list[float] = []
    unit_count = 0
    correlation_values: list[float] = []
    candidate_closer = 0

    for index, row in enumerate(rows, start=1):
        codes = np.load(row["codes_path"]).astype(np.int64, copy=False)
        units, original = collapse_consecutive(torch.from_numpy(codes).long())
        baseline_duration = predict(baseline, units, device)
        candidate_duration = predict(candidate, units, device)
        original_total_value = float(original.sum())
        baseline_total_value = float(baseline_duration.sum())
        candidate_total_value = float(candidate_duration.sum())
        if original_total_value <= 0.0:
            raise ValueError(f"Non-positive original duration: {row['id']}")
        original_total += original_total_value
        baseline_total += baseline_total_value
        candidate_total += candidate_total_value
        baseline_rel_errors.append(
            abs(baseline_total_value - original_total_value)
            / original_total_value
        )
        candidate_rel_errors.append(
            abs(candidate_total_value - original_total_value)
            / original_total_value
        )
        if abs(candidate_total_value - original_total_value) < abs(
            baseline_total_value - original_total_value
        ):
            candidate_closer += 1
        if units.numel() > 1:
            left = baseline_duration.numpy()
            right = candidate_duration.numpy()
            if float(left.std()) > 1e-8 and float(right.std()) > 1e-8:
                correlation_values.append(float(np.corrcoef(left, right)[0, 1]))
        unit_count += int(units.numel())
        if index % 250 == 0 or index == len(rows):
            print(f"processed={index}/{len(rows)}", flush=True)

    result = {
        "records": len(rows),
        "collapsed_units": unit_count,
        "baseline_model": str(Path(args.baseline_model).resolve()),
        "baseline_sha256": sha256_file(args.baseline_model),
        "candidate_model": str(Path(args.candidate_model).resolve()),
        "candidate_sha256": sha256_file(args.candidate_model),
        "original_total_frames": original_total,
        "baseline_total_frames": baseline_total,
        "candidate_total_frames": candidate_total,
        "baseline_global_ratio": baseline_total / original_total,
        "candidate_global_ratio": candidate_total / original_total,
        "baseline_mean_abs_total_relative_error": float(
            np.mean(baseline_rel_errors)
        ),
        "candidate_mean_abs_total_relative_error": float(
            np.mean(candidate_rel_errors)
        ),
        "candidate_closer_to_original": candidate_closer,
        "candidate_closer_fraction": candidate_closer / len(rows),
        "mean_baseline_candidate_unit_correlation": (
            float(np.mean(correlation_values)) if correlation_values else None
        ),
        "finite": all(
            math.isfinite(value)
            for value in (original_total, baseline_total, candidate_total)
        ),
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
