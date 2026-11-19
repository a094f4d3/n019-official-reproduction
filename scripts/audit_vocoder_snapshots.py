#!/usr/bin/env python3
"""Summarize lightweight metadata embedded in generator snapshots."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import torch


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--snapshots", nargs="+", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    rows = []
    for raw_path in args.snapshots:
        path = Path(raw_path)
        checkpoint = torch.load(
            path,
            map_location="cpu",
            weights_only=False,
        )
        rows.append(
            {
                "path": str(path.resolve()),
                "sha256": sha256_file(path),
                "step": checkpoint.get("step"),
                "epoch": checkpoint.get("epoch"),
                "validation_mel_l1": checkpoint.get("validation_mel_l1"),
                "selection_policy": checkpoint.get("selection_policy"),
                "recipe": checkpoint.get("recipe"),
            }
        )
        del checkpoint

    result = {"snapshots": rows}
    output = Path(args.out)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
