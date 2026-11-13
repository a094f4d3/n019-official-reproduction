"""Check inference-time duration predictions before full-dataset synthesis."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch

from n019.anonymize import EmbeddingStore
from n019.audio import (
    collapse_consecutive,
    round_durations_with_residual,
    sanitize_predicted_durations,
)
from n019.duration import load_duration_checkpoint
from n019.manifest import iter_jsonl, sha256_file, utterance_id, write_json


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--unit-records", required=True)
    parser.add_argument("--target-map", required=True)
    parser.add_argument("--duration-model", required=True)
    parser.add_argument("--duration-embeddings", default=None)
    parser.add_argument(
        "--target-embedding-key",
        choices=["target_id", "target_speaker"],
        default="target_id",
    )
    parser.add_argument("--out", required=True)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--device", default="cpu")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA/DCU requested but unavailable")
    device = torch.device(args.device)
    model, checkpoint = load_duration_checkpoint(
        args.duration_model,
        device=device,
    )
    speaker_dim = int(checkpoint["model_config"]["speaker_dim"])
    if speaker_dim > 0 and not args.duration_embeddings:
        raise ValueError(
            "--duration-embeddings is required for conditioned models"
        )
    embeddings = (
        EmbeddingStore(
            args.duration_embeddings,
            expected_dim=speaker_dim,
        )
        if speaker_dim > 0
        else None
    )
    unit_rows = list(iter_jsonl(args.unit_records))
    if args.limit:
        unit_rows = unit_rows[: args.limit]
    targets = {
        row["source_id"]: row
        for row in iter_jsonl(args.target_map)
    }
    raw_values = []
    rounded_values = []
    values = []
    raw_relative_errors = []
    rounded_relative_errors = []
    unit_absolute_errors = []
    unit_squared_errors = []
    waveform_duration_deltas = []
    negative_utterances = 0
    negative_values = 0
    zero_values = 0
    nonfinite_utterances = 0
    with torch.inference_mode():
        for index, row in enumerate(unit_rows, 1):
            identifier = utterance_id(row)
            if identifier not in targets:
                raise KeyError(f"Missing target mapping for {identifier}")
            codes = np.load(row["codes_path"]).astype(np.int64, copy=False)
            units, original = collapse_consecutive(torch.from_numpy(codes))
            target = targets[identifier]
            speaker = (
                embeddings.get(target[args.target_embedding_key])
                .unsqueeze(0)
                .to(device)
                if embeddings is not None
                else None
            )
            prediction = model(units.unsqueeze(0).to(device), speaker)[0].cpu()
            if not bool(torch.isfinite(prediction).all()):
                nonfinite_utterances += 1
                continue
            negative = int((prediction < 0).sum())
            negative_values += negative
            if negative:
                negative_utterances += 1
            zero_values += int((prediction == 0).sum())
            sanitized, _ = sanitize_predicted_durations(prediction)
            rounded = round_durations_with_residual(
                sanitized,
                minimum_one=True,
            )
            raw_values.append(prediction)
            values.append(sanitized)
            rounded_values.append(rounded.float())
            original_total = float(original.sum())
            raw_relative_errors.append(
                abs(float(prediction.sum()) - original_total)
                / max(1.0, original_total)
            )
            rounded_relative_errors.append(
                abs(float(rounded.sum()) - original_total)
                / max(1.0, original_total)
            )
            error = prediction - original.float()
            unit_absolute_errors.append(float(error.abs().sum()))
            unit_squared_errors.append(float(error.square().sum()))
            audio_path = row.get("audio")
            if audio_path:
                try:
                    import soundfile as sf

                    source_seconds = float(sf.info(audio_path).duration)
                    generated_seconds = float(rounded.sum()) * 0.02
                    waveform_duration_deltas.append(
                        abs(generated_seconds - source_seconds)
                    )
                except (OSError, RuntimeError):
                    pass
            if index % 200 == 0:
                print(f"diagnosed={index}/{len(unit_rows)}", flush=True)
    if not values:
        raise RuntimeError("No finite duration predictions")
    raw_combined = torch.cat(raw_values).numpy()
    combined = torch.cat(values).numpy()
    rounded_combined = torch.cat(rounded_values).numpy()
    total_units = max(1, int(combined.size))
    result = {
        "input_sha256": {
            "unit_records": sha256_file(args.unit_records),
            "target_map": sha256_file(args.target_map),
            "duration_model": sha256_file(args.duration_model),
            **(
                {
                    "duration_embeddings": sha256_file(
                        args.duration_embeddings
                    )
                }
                if args.duration_embeddings
                else {}
            ),
        },
        "utterances": len(values),
        "unit_values": int(combined.size),
        "negative_utterances": negative_utterances,
        "negative_values": negative_values,
        "zero_values": zero_values,
        "nonfinite_utterances": nonfinite_utterances,
        "duration_mean_from_checkpoint": float(
            model.duration_mean.detach().cpu()
        ),
        "duration_std_from_checkpoint": float(
            model.duration_std.detach().cpu()
        ),
        "duration_min": float(combined.min()),
        "duration_max": float(combined.max()),
        "duration_mean": float(combined.mean()),
        "duration_quantiles": {
            str(q): float(np.quantile(combined, q))
            for q in (0.0, 0.01, 0.05, 0.5, 0.95, 0.99, 1.0)
        },
        "raw_duration_min": float(raw_combined.min()),
        "raw_duration_max": float(raw_combined.max()),
        "raw_duration_mean": float(raw_combined.mean()),
        "raw_negative_values": int((raw_combined < 0).sum()),
        "unit_mae_vs_original": float(
            sum(unit_absolute_errors) / total_units
        ),
        "unit_rmse_vs_original": float(
            np.sqrt(sum(unit_squared_errors) / total_units)
        ),
        "raw_total_duration_relative_error_mean": float(
            np.mean(raw_relative_errors)
        ),
        "raw_total_duration_relative_error_p95": float(
            np.quantile(raw_relative_errors, 0.95)
        ),
        "rounded_total_duration_relative_error_mean": float(
            np.mean(rounded_relative_errors)
        ),
        "rounded_total_duration_relative_error_p95": float(
            np.quantile(rounded_relative_errors, 0.95)
        ),
        "rounded_duration_min": float(rounded_combined.min()),
        "rounded_duration_max": float(rounded_combined.max()),
        "rounded_duration_mean": float(rounded_combined.mean()),
        "rounded_duration_quantiles": {
            str(q): float(np.quantile(rounded_combined, q))
            for q in (0.0, 0.01, 0.05, 0.5, 0.95, 0.99, 1.0)
        },
        "waveform_duration_abs_error_mean": (
            float(np.mean(waveform_duration_deltas))
            if waveform_duration_deltas
            else None
        ),
        "waveform_duration_abs_error_p95": (
            float(np.quantile(waveform_duration_deltas, 0.95))
            if waveform_duration_deltas
            else None
        ),
        "target_speaker_dim": speaker_dim,
        "target_embedding_key": args.target_embedding_key,
        "device": str(device),
    }
    write_json(args.out, result)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
