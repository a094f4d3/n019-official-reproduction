#!/usr/bin/env python3
"""Write the target-embedding subset referenced by a target map."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-map", required=True)
    parser.add_argument("--embeddings", required=True)
    parser.add_argument("--key", default="target_id")
    parser.add_argument("--dimension", type=int, default=250)
    parser.add_argument(
        "--allow-nonunit",
        action="store_true",
        help=(
            "Preserve finite non-unit vectors. Required for raw ECAPA speaker "
            "means, which the ECAPA duration model consumes without inference "
            "normalization."
        ),
    )
    parser.add_argument("--out", required=True)
    parser.add_argument("--summary", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    map_path = Path(args.target_map)
    required: set[str] = set()
    with map_path.open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                required.add(str(json.loads(line)[args.key]))

    archive = np.load(args.embeddings, allow_pickle=False)
    try:
        missing = sorted(required - set(archive.files))
        if missing:
            raise KeyError(
                f"missing {len(missing)} target embeddings; first={missing[:10]}"
            )
        output = {}
        for key in sorted(required):
            value = np.asarray(archive[key], dtype=np.float32)
            if value.shape != (args.dimension,):
                raise ValueError(f"{key} has shape {value.shape}")
            if not np.isfinite(value).all():
                raise ValueError(f"{key} contains non-finite values")
            norm = float(np.linalg.norm(value))
            if not args.allow_nonunit and abs(norm - 1.0) > 1e-4:
                raise ValueError(f"{key} has norm {norm}")
            output[key] = value
    finally:
        archive.close()

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(out_path, **output)
    summary = {
        "target_map": str(map_path.resolve()),
        "embeddings": str(Path(args.embeddings).resolve()),
        "embedding_key": args.key,
        "keys": len(output),
        "dimension": args.dimension,
        "finite": True,
        "unit_norm": None if args.allow_nonunit else True,
        "out": str(out_path.resolve()),
        "out_sha256": hashlib.sha256(out_path.read_bytes()).hexdigest(),
    }
    summary_path = Path(args.summary)
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
