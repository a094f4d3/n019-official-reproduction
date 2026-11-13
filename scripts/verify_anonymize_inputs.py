#!/usr/bin/env python3
"""Validate the complete LS360 inputs before a formal anonymisation run."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(16 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_jsonl(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                rows.append(json.loads(line))
    return rows


def require_unique(values: list[str], label: str) -> set[str]:
    if len(set(values)) != len(values):
        raise ValueError(f"{label} contains duplicate IDs")
    return set(values)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--vpc-wav-scp", type=Path, required=True)
    parser.add_argument("--target-embeddings", type=Path, required=True)
    parser.add_argument("--artifact", type=Path, action="append", default=[])
    parser.add_argument("--expected-source", type=int, default=104014)
    parser.add_argument("--expected-targets", type=int, default=81605)
    parser.add_argument("--target-dim", type=int, default=250)
    parser.add_argument(
        "--target-embedding-key",
        choices=["target_id", "target_speaker"],
        default="target_id",
    )
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    source_manifest = (
        args.data_root / "processed/manifests/librispeech_train_clean_360.jsonl"
    )
    unit_records = (
        args.data_root
        / "processed/units/librispeech_train_clean_360/unit_records.jsonl"
    )
    target_map = (
        args.data_root
        / "processed/targets/librispeech_train_clean_360_target_map_utterance.jsonl"
    )
    for path in (
        source_manifest,
        unit_records,
        target_map,
        args.vpc_wav_scp,
        args.target_embeddings,
        *args.artifact,
    ):
        if not path.is_file():
            raise FileNotFoundError(path)

    sources = read_jsonl(source_manifest)
    units = read_jsonl(unit_records)
    mappings = read_jsonl(target_map)
    source_ids = require_unique([str(row["id"]) for row in sources], "source")
    unit_ids = require_unique([str(row["id"]) for row in units], "units")
    map_source_ids = require_unique(
        [str(row["source_id"]) for row in mappings], "target map source"
    )
    target_ids = {str(row["target_id"]) for row in mappings}
    target_speakers = {str(row["target_speaker"]) for row in mappings}
    expected_embedding_keys = (
        target_ids
        if args.target_embedding_key == "target_id"
        else target_speakers
    )
    vpc_ids = {
        line.split()[0]
        for line in args.vpc_wav_scp.read_text(encoding="utf-8").splitlines()
        if line.strip()
    }

    archive = np.load(args.target_embeddings, allow_pickle=False)
    embedding_ids = set(archive.files)
    dimensions = set()
    norm_min = float("inf")
    norm_max = 0.0
    nonfinite = 0
    for key in archive.files:
        value = archive[key]
        dimensions.add(int(value.size))
        if not np.isfinite(value).all():
            nonfinite += 1
        norm = float(np.linalg.norm(value))
        norm_min = min(norm_min, norm)
        norm_max = max(norm_max, norm)

    checks = {
        "source_rows": len(sources) == args.expected_source,
        "unit_rows": len(units) == args.expected_source,
        "target_map_rows": len(mappings) == args.expected_source,
        "vpc_rows": len(vpc_ids) == args.expected_source,
        "source_ids_match_units": source_ids == unit_ids,
        "source_ids_match_target_map": source_ids == map_source_ids,
        "source_ids_match_vpc": source_ids == vpc_ids,
        "target_count": len(target_ids) == args.expected_targets,
        "target_keys_match_embeddings": expected_embedding_keys == embedding_ids,
        "target_dimensions": dimensions == {args.target_dim},
        "target_finite": nonfinite == 0,
        "target_l2_normalized": 0.999 <= norm_min and norm_max <= 1.001,
    }
    report = {
        "source_manifest": str(source_manifest),
        "source_manifest_sha256": sha256_file(source_manifest),
        "unit_records": str(unit_records),
        "unit_records_sha256": sha256_file(unit_records),
        "target_map": str(target_map),
        "target_map_sha256": sha256_file(target_map),
        "vpc_wav_scp": str(args.vpc_wav_scp),
        "vpc_wav_scp_sha256": sha256_file(args.vpc_wav_scp),
        "target_embeddings": str(args.target_embeddings),
        "target_embeddings_sha256": sha256_file(args.target_embeddings),
        "source_rows": len(sources),
        "unit_rows": len(units),
        "target_map_rows": len(mappings),
        "vpc_rows": len(vpc_ids),
        "unique_targets": len(target_ids),
        "unique_target_speakers": len(target_speakers),
        "target_embedding_key": args.target_embedding_key,
        "embedding_keys": len(embedding_ids),
        "embedding_dimensions": sorted(dimensions),
        "nonfinite_embeddings": nonfinite,
        "embedding_norm_min": norm_min,
        "embedding_norm_max": norm_max,
        "artifacts": [
            {
                "path": str(path),
                "bytes": path.stat().st_size,
                "sha256": sha256_file(path),
            }
            for path in args.artifact
        ],
        "checks": checks,
        "passed": all(checks.values()),
    }
    encoded = json.dumps(report, indent=2, sort_keys=True)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    if not report["passed"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
