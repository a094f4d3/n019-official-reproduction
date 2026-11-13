#!/usr/bin/env python3
"""Merge target-speaker mean embeddings and optionally apply shrink."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--base-embeddings",
        required=True,
        help="Existing 843-key mean32 archive used to define the shrink centroid",
    )
    parser.add_argument(
        "--additional-embeddings",
        action="append",
        default=[],
        help="Additional raw speaker-mean archive",
    )
    parser.add_argument("--out", required=True)
    parser.add_argument(
        "--shrink",
        type=float,
        default=0.0,
        help="Weight of the base-archive centroid, e.g. 0.1",
    )
    parser.add_argument("--metadata", required=True)
    parser.add_argument("--expected-keys", type=int)
    return parser.parse_args()


def load_archive(path: Path) -> dict[str, np.ndarray]:
    archive = np.load(path, allow_pickle=False)
    try:
        return {
            str(key): archive[key].astype(np.float32)
            for key in archive.files
        }
    finally:
        archive.close()


def main() -> int:
    args = parse_args()
    if not 0.0 <= args.shrink < 1.0:
        raise ValueError("--shrink must be in [0, 1)")

    base_path = Path(args.base_embeddings)
    base = load_archive(base_path)
    combined = dict(base)
    sources = [str(base_path.resolve())]
    for raw_path in args.additional_embeddings:
        path = Path(raw_path)
        sources.append(str(path.resolve()))
        for key, value in load_archive(path).items():
            if key in combined:
                if not np.array_equal(combined[key], value):
                    raise ValueError(f"Conflicting embeddings for key {key}")
                continue
            combined[key] = value

    dimensions = {int(value.size) for value in combined.values()}
    if dimensions != {250}:
        raise ValueError(f"Expected 250-D embeddings, found {dimensions}")
    if not all(np.isfinite(value).all() for value in combined.values()):
        raise ValueError("Found non-finite embedding values")
    if args.expected_keys is not None and len(combined) != args.expected_keys:
        raise ValueError(
            f"Expected {args.expected_keys} keys, found {len(combined)}"
        )

    keys = sorted(combined)
    matrix = np.stack([combined[key] for key in keys]).astype(np.float64)
    base_matrix = np.stack([base[key] for key in sorted(base)]).astype(np.float64)
    centroid = base_matrix.mean(axis=0)
    centroid /= np.linalg.norm(centroid)
    if args.shrink > 0.0:
        matrix = (
            (1.0 - args.shrink) * matrix
            + args.shrink * centroid[None, :]
        )
    matrix /= np.linalg.norm(matrix, axis=1, keepdims=True)
    matrix = matrix.astype(np.float32)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(
        out,
        **{key: matrix[index] for index, key in enumerate(keys)},
    )
    metadata = {
        "rows": len(keys),
        "dimension": 250,
        "shrink_weight": args.shrink,
        "centroid_source": str(base_path.resolve()),
        "centroid_rows": len(base),
        "sources": sources,
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
