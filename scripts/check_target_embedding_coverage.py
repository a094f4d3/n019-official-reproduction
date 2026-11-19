#!/usr/bin/env python3
"""Compare target-map keys with a target embedding archive."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-map", required=True, type=Path)
    parser.add_argument("--embeddings", required=True, type=Path)
    parser.add_argument("--key", default="target_speaker")
    args = parser.parse_args()

    required = {
        str(json.loads(line)[args.key])
        for line in args.target_map.read_text(encoding="utf-8").splitlines()
        if line.strip()
    }
    archive = np.load(args.embeddings, allow_pickle=False)
    try:
        available = set(archive.files)
    finally:
        archive.close()
    print(
        json.dumps(
            {
                "required": len(required),
                "available": len(available),
                "missing_count": len(required - available),
                "extra_count": len(available - required),
                "missing_examples": sorted(required - available)[:10],
                "required_examples": sorted(required)[:10],
                "available_examples": sorted(available)[:10],
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
