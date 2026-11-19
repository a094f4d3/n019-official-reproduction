#!/usr/bin/env python3
"""Validate layer-9 unit extraction outputs before downstream training."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--units", required=True, type=Path)
    parser.add_argument("--expected-rows", type=int, default=33236)
    parser.add_argument("--layer", type=int, default=9)
    parser.add_argument("--k", type=int, default=200)
    args = parser.parse_args()

    records = args.units / "unit_records.jsonl"
    metadata_path = args.units / "units_metadata.json"
    rows = sum(1 for line in records.open(encoding="utf-8") if line.strip())
    if rows != args.expected_rows:
        raise SystemExit(f"Unexpected record count: {rows}")
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    expected = {
        "records": args.expected_rows,
        "hubert_layer": args.layer,
        "kmeans_k": args.k,
    }
    mismatches = {
        key: {"expected": value, "actual": metadata.get(key)}
        for key, value in expected.items()
        if metadata.get(key) != value
    }
    if mismatches:
        raise SystemExit(f"Metadata mismatch: {mismatches}")
    archive = np.load(metadata["codebook"], allow_pickle=False)
    centroids = archive["centroids"]
    codebook_metadata = json.loads(str(archive["metadata_json"].item()))
    archive.close()
    if centroids.shape[0] != args.k:
        raise SystemExit(f"Unexpected codebook shape: {centroids.shape}")
    if not np.isfinite(centroids).all():
        raise SystemExit("Codebook contains non-finite values")
    if codebook_metadata.get("layer") != args.layer:
        raise SystemExit(
            f"Codebook layer mismatch: {codebook_metadata.get('layer')}"
        )
    print(
        json.dumps(
            {
                "rows": rows,
                "layer": metadata["hubert_layer"],
                "k": metadata["kmeans_k"],
                "centroids": list(centroids.shape),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
