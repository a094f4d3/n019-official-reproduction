#!/usr/bin/env python3
"""Mix target-speaker and target-utterance embeddings for an A/B diagnostic."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-map", required=True)
    parser.add_argument("--speaker-embeddings", required=True)
    parser.add_argument("--utterance-embeddings", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--metadata", required=True)
    parser.add_argument(
        "--utterance-weight",
        type=float,
        required=True,
        help="Weight of the target-utterance vector after L2 normalization",
    )
    parser.add_argument("--speaker-key", default="target_speaker")
    parser.add_argument("--utterance-key", default="target_id")
    return parser.parse_args()


def load_archive(path: Path) -> dict[str, np.ndarray]:
    archive = np.load(path, allow_pickle=False)
    try:
        return {
            str(key): archive[key].astype(np.float64)
            for key in archive.files
        }
    finally:
        archive.close()


def validate_vector(key: str, value: np.ndarray) -> None:
    if value.shape != (250,):
        raise ValueError(f"{key} has shape {value.shape}, expected (250,)")
    if not np.isfinite(value).all():
        raise ValueError(f"{key} contains non-finite values")
    norm = float(np.linalg.norm(value))
    if abs(norm - 1.0) > 1e-4:
        raise ValueError(f"{key} has norm {norm}, expected 1")


def main() -> int:
    args = parse_args()
    weight = float(args.utterance_weight)
    if not 0.0 <= weight <= 1.0:
        raise ValueError("--utterance-weight must be in [0, 1]")

    mappings = [
        json.loads(line)
        for line in Path(args.target_map).read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if not mappings:
        raise ValueError("Target map is empty")

    rows_by_utterance: dict[str, dict] = {}
    for row in mappings:
        key = str(row[args.utterance_key])
        if key in rows_by_utterance:
            existing = rows_by_utterance[key]
            if str(row[args.speaker_key]) != str(existing[args.speaker_key]):
                raise ValueError(
                    f"Inconsistent {args.speaker_key} for duplicate "
                    f"{args.utterance_key}: {key}"
                )
            continue
        rows_by_utterance[key] = row
    speaker_keys = {str(row[args.speaker_key]) for row in mappings}
    utterance_keys = set(rows_by_utterance)
    speakers = load_archive(Path(args.speaker_embeddings))
    utterances = load_archive(Path(args.utterance_embeddings))

    missing_speakers = speaker_keys - set(speakers)
    missing_utterances = utterance_keys - set(utterances)
    if missing_speakers:
        raise ValueError(
            "Missing speaker embeddings: "
            f"{len(missing_speakers)}; first: {sorted(missing_speakers)[:10]}"
        )
    if missing_utterances:
        raise ValueError(
            "Missing utterance embeddings: "
            f"{len(missing_utterances)}; first: {sorted(missing_utterances)[:10]}"
        )

    for key in sorted(speaker_keys):
        validate_vector(f"speaker:{key}", speakers[key])
    for key in sorted(utterance_keys):
        validate_vector(f"utterance:{key}", utterances[key])

    output: dict[str, np.ndarray] = {}
    for key in sorted(utterance_keys):
        row = rows_by_utterance[key]
        speaker_key = str(row[args.speaker_key])
        mixed = (
            (1.0 - weight) * speakers[speaker_key]
            + weight * utterances[key]
        )
        norm = float(np.linalg.norm(mixed))
        if not np.isfinite(norm) or norm <= 0.0:
            raise ValueError(f"Invalid mixed embedding norm for {key}: {norm}")
        mixed = (mixed / norm).astype(np.float32)
        validate_vector(f"mixed:{key}", mixed)
        output[key] = mixed

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(out, **output)
    metadata = {
        "target_map": str(Path(args.target_map).resolve()),
        "speaker_embeddings": str(Path(args.speaker_embeddings).resolve()),
        "utterance_embeddings": str(Path(args.utterance_embeddings).resolve()),
        "utterance_weight": weight,
        "rows": len(mappings),
        "speaker_keys": len(speaker_keys),
        "utterance_keys": len(utterance_keys),
        "dimension": 250,
        "output_key": args.utterance_key,
        "out": str(out.resolve()),
        "out_sha256": hashlib.sha256(out.read_bytes()).hexdigest(),
    }
    metadata_path = Path(args.metadata)
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(metadata, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
