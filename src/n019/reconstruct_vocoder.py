"""Reconstruct fixed validation speech with a candidate vocoder checkpoint."""

from __future__ import annotations

import argparse
import math
import shutil
import time
from pathlib import Path

import numpy as np
import torch

from n019.anonymize import EmbeddingStore, estimate_pcm16_wav_bytes, require_free_space
from n019.audio import (
    PAD_UNIT_ID,
    collapse_consecutive,
    expand_units,
    round_durations_with_residual,
    sanitize_predicted_durations,
    save_audio,
)
from n019.duration import load_duration_checkpoint
from n019.manifest import (
    iter_jsonl,
    safe_filename,
    sha256_file,
    speaker_id,
    utterance_id,
    write_json,
    write_jsonl,
)
from n019.vocoder import load_generator


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-manifest", required=True)
    parser.add_argument("--unit-records", required=True)
    parser.add_argument("--vocoder", required=True)
    parser.add_argument("--vocoder-type", choices=["nt", "ecapa"], required=True)
    parser.add_argument("--vocoder-embeddings", required=True)
    parser.add_argument("--duration-mode", choices=["orig", "pred"], required=True)
    parser.add_argument("--duration-model", default=None)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--space-safety-factor", type=float, default=1.1)
    parser.add_argument("--device", default="cuda")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA/DCU requested but unavailable")
    if args.limit < 0:
        raise ValueError("--limit must be non-negative")
    if args.space_safety_factor < 1.0:
        raise ValueError("--space-safety-factor must be at least 1.0")
    if args.duration_mode == "pred" and not args.duration_model:
        raise ValueError("--duration-model is required for pred mode")

    device = torch.device(args.device)
    generator, generator_checkpoint = load_generator(args.vocoder, device)
    expected_dim = 250 if args.vocoder_type == "nt" else 192
    configured_dim = generator_checkpoint["config"].get("speaker_dim")
    if configured_dim != expected_dim:
        raise ValueError(
            f"Vocoder speaker_dim={configured_dim}, expected {expected_dim}"
        )
    embeddings = EmbeddingStore(
        args.vocoder_embeddings,
        expected_dim=expected_dim,
    )
    duration_model = None
    if args.duration_mode == "pred":
        duration_model, duration_checkpoint = load_duration_checkpoint(
            args.duration_model,
            device=device,
        )
        if int(duration_checkpoint["model_config"]["speaker_dim"]) != 0:
            raise ValueError(
                "Selection reconstruction currently requires an unconditional "
                "duration predictor"
            )

    sources = list(iter_jsonl(args.source_manifest))
    if args.limit:
        sources = sources[: args.limit]
    if not sources:
        raise ValueError("Source manifest selection is empty")
    unit_rows = list(iter_jsonl(args.unit_records))
    unit_records = {utterance_id(row): row for row in unit_rows}
    if len(unit_records) != len(unit_rows):
        raise ValueError("Unit records contain duplicate IDs")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    missing_seconds = [
        utterance_id(row) for row in sources if row.get("seconds") is None
    ]
    if missing_seconds:
        raise ValueError(
            "Source manifest is missing seconds for space estimation: "
            f"{missing_seconds[:5]}"
        )
    estimated_bytes = sum(
        estimate_pcm16_wav_bytes(float(row["seconds"])) for row in sources
    )
    require_free_space(
        required_bytes=int(
            math.ceil(estimated_bytes * args.space_safety_factor)
        ),
        available_bytes=shutil.disk_usage(out_dir).free,
    )

    rows = []
    started = time.time()
    negative_values = 0
    with torch.inference_mode():
        for index, source in enumerate(sources, 1):
            identifier = utterance_id(source)
            if identifier not in unit_records:
                raise KeyError(f"Missing unit record for {identifier}")
            unit_row = unit_records[identifier]
            codes = torch.from_numpy(
                np.load(unit_row["codes_path"]).astype(np.int64, copy=False)
            )
            if codes.numel() == 0:
                raise ValueError(f"Empty code sequence for {identifier}")
            if int(codes.min()) < 0 or int(codes.max()) >= PAD_UNIT_ID:
                raise ValueError(f"Invalid units for {identifier}")
            units, durations = collapse_consecutive(codes)
            if args.duration_mode == "pred":
                assert duration_model is not None
                predicted = duration_model(
                    units.unsqueeze(0).to(device)
                )[0].cpu()
                predicted, negative = sanitize_predicted_durations(predicted)
                negative_values += negative
                durations = round_durations_with_residual(
                    predicted,
                    minimum_one=True,
                )
            speaker_key = speaker_id(source)
            speaker = embeddings.get(speaker_key).unsqueeze(0).to(device)
            expanded = expand_units(units, durations).unsqueeze(0).to(device)
            waveform = generator(expanded, speaker)[0, 0]
            output_path = out_dir / safe_filename(identifier, ".wav")
            save_audio(output_path, waveform.float().cpu())
            rows.append(
                {
                    **source,
                    "id": identifier,
                    "audio": str(output_path),
                    "source_audio": source["audio"],
                    "vocoder_type": args.vocoder_type,
                    "duration_mode": args.duration_mode,
                    "duration_frames": int(durations.sum()),
                    "negative_duration_values": negative,
                }
            )
            if index == 1 or index % 25 == 0 or index == len(sources):
                print(
                    f"reconstructed={index}/{len(sources)} "
                    f"elapsed={time.time() - started:.1f}s",
                    flush=True,
                )

    write_jsonl(out_dir / "reconstructed.jsonl", rows)
    write_json(
        out_dir / "run_meta.json",
        {
            "records": len(rows),
            "negative_duration_values": negative_values,
            "elapsed_seconds": time.time() - started,
            "args": vars(args),
            "vocoder_step": generator_checkpoint.get("step"),
            "input_sha256": {
                "source_manifest": sha256_file(args.source_manifest),
                "unit_records": sha256_file(args.unit_records),
                "vocoder": sha256_file(args.vocoder),
                "vocoder_embeddings": sha256_file(args.vocoder_embeddings),
                **(
                    {"duration_model": sha256_file(args.duration_model)}
                    if args.duration_model
                    else {}
                ),
            },
        },
    )
    print(out_dir / "reconstructed.jsonl")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
