#!/usr/bin/env python3
"""Verify the training units and speaker embeddings used by N019."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(16 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_jsonl(path: Path) -> list[dict]:
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def verify_units(
    processed: Path,
    name: str,
    expected_records: int,
    expected_speakers: int,
    codebook: Path,
    codebook_sha256: str,
) -> dict:
    root = processed / "units" / name
    records_path = root / "unit_records.jsonl"
    metadata_path = root / "units_metadata.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    rows = read_jsonl(records_path)
    identifiers = [row["id"] for row in rows]
    speakers = {str(row["speaker"]) for row in rows}
    missing = [row["codes_path"] for row in rows if not Path(row["codes_path"]).is_file()]
    shape_mismatches = []
    for row in rows:
        codes = np.load(row["codes_path"], mmap_mode="r")
        if codes.ndim != 1 or codes.shape[0] != int(row["num_frames"]):
            shape_mismatches.append(row["id"])
        if codes.size and (int(codes.min()) < 0 or int(codes.max()) >= 200):
            shape_mismatches.append(row["id"])
    temporary = sorted((root / "codes").glob("*.tmp.npy"))
    result = {
        "name": name,
        "records": len(rows),
        "unique_ids": len(set(identifiers)),
        "speakers": len(speakers),
        "metadata_records": metadata["records"],
        "metadata_speakers": metadata["speakers"],
        "missing_code_files": len(missing),
        "shape_or_value_mismatches": len(shape_mismatches),
        "temporary_code_files": len(temporary),
        "temporary_examples": [path.name for path in temporary[:5]],
        "codebook": str(codebook),
        "codebook_sha256": codebook_sha256,
        "metadata_codebook_sha256": metadata["codebook_sha256"],
    }
    if len(rows) != expected_records:
        raise ValueError(f"{name}: expected {expected_records} records")
    if len(set(identifiers)) != len(rows):
        raise ValueError(f"{name}: duplicate utterance IDs")
    if len(speakers) != expected_speakers:
        raise ValueError(f"{name}: expected {expected_speakers} speakers")
    if missing or shape_mismatches:
        raise ValueError(f"{name}: incomplete code arrays")
    if metadata["codebook_sha256"] != codebook_sha256:
        raise ValueError(f"{name}: codebook hash mismatch")
    return result


def verify_speakers(
    processed: Path,
    name: str,
    expected_speakers: int,
) -> dict:
    root = processed / "embeddings" / name
    embeddings_path = root / "nt_speaker_embeddings.npz"
    metadata = json.loads((root / "metadata.json").read_text(encoding="utf-8"))
    archive = np.load(embeddings_path, allow_pickle=False)
    norms = [float(np.linalg.norm(archive[key])) for key in archive.files]
    result = {
        "name": name,
        "speakers": len(archive.files),
        "metadata_speakers": metadata["speakers"],
        "dimensions": sorted({int(archive[key].size) for key in archive.files}),
        "norm_min": min(norms),
        "norm_max": max(norms),
    }
    if len(archive.files) != expected_speakers:
        raise ValueError(f"{name}: expected {expected_speakers} speakers")
    if result["dimensions"] != [250]:
        raise ValueError(f"{name}: expected 250-D embeddings")
    if not all(0.999 <= norm <= 1.001 for norm in norms):
        raise ValueError(f"{name}: embeddings are not L2-normalized")
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--processed", required=True)
    parser.add_argument("--out", default=None)
    args = parser.parse_args()
    processed = Path(args.processed).resolve()
    codebook = (
        processed
        / "units/librispeech_train_clean_100/kmeans_k200_seed20261102.npz"
    )
    codebook_sha256 = sha256_file(codebook)
    centroids = np.load(codebook, allow_pickle=False)["centroids"]
    if centroids.shape != (200, 768):
        raise ValueError(f"Unexpected codebook shape: {centroids.shape}")
    report = {
        "codebook_shape": list(centroids.shape),
        "codebook_sha256": codebook_sha256,
        "librispeech": verify_units(
            processed,
            "librispeech_train_clean_100",
            28_539,
            251,
            codebook,
            codebook_sha256,
        ),
        "librispeech_speakers": verify_speakers(
            processed,
            "librispeech_train_clean_100_nt",
            251,
        ),
        "libritts": verify_units(
            processed,
            "libritts_train_clean_100",
            33_236,
            247,
            codebook,
            codebook_sha256,
        ),
        "libritts_speakers": verify_speakers(
            processed,
            "libritts_train_clean_100_nt",
            247,
        ),
    }
    encoded = json.dumps(report, indent=2, sort_keys=True)
    if args.out:
        Path(args.out).write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
