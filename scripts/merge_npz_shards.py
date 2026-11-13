#!/usr/bin/env python3
"""Strictly merge disjoint NPZ shards with identical vector dimensions."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import numpy as np


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", action="append", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--summary", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output: dict[str, np.ndarray] = {}
    dimensions: set[tuple[int, ...]] = set()
    shard_rows = []
    for raw_path in args.input:
        path = Path(raw_path)
        with np.load(path, allow_pickle=False) as archive:
            keys = sorted(archive.files)
            for key in keys:
                if key in output:
                    raise ValueError(f"duplicate key across shards: {key}")
                value = np.asarray(archive[key], dtype=np.float32)
                if not np.isfinite(value).all():
                    raise ValueError(f"non-finite value for {key} in {path}")
                output[key] = value
                dimensions.add(tuple(value.shape))
        shard_rows.append({"path": str(path.resolve()), "keys": len(keys)})
    if not output:
        raise ValueError("merged output is empty")
    if len(dimensions) != 1:
        raise ValueError(f"mixed vector shapes: {sorted(dimensions)}")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    temporary = out.with_suffix(out.suffix + ".tmp")
    with temporary.open("wb") as handle:
        np.savez(handle, **{key: output[key] for key in sorted(output)})
    os.replace(temporary, out)
    summary = {
        "keys": len(output),
        "shape": list(next(iter(dimensions))),
        "shards": shard_rows,
        "out": str(out.resolve()),
    }
    Path(args.summary).write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
