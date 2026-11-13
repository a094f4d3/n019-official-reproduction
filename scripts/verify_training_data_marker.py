#!/usr/bin/env python3
"""Verify a previously audited training-data marker cheaply."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--records", required=True, type=Path)
    parser.add_argument("--embeddings", required=True, type=Path)
    parser.add_argument("--marker", required=True, type=Path)
    parser.add_argument("--expected-rows", required=True, type=int)
    args = parser.parse_args()

    marker = json.loads(args.marker.read_text(encoding="utf-8"))
    expected = {
        "records_rows": args.expected_rows,
        "records_sha256": sha256_file(args.records),
        "embeddings_sha256": sha256_file(args.embeddings),
    }
    mismatches = {
        key: {"marker": marker.get(key), "current": value}
        for key, value in expected.items()
        if marker.get(key) != value
    }
    if mismatches:
        raise SystemExit(
            "Training-data marker does not match current inputs: "
            + json.dumps(mismatches, sort_keys=True)
        )
    rows = sum(1 for line in args.records.open(encoding="utf-8") if line.strip())
    if rows != args.expected_rows:
        raise SystemExit(f"Unexpected record count: {rows} != {args.expected_rows}")
    print(
        json.dumps(
            {
                "marker": str(args.marker.resolve()),
                "records_rows": rows,
                "records_sha256": expected["records_sha256"],
                "embeddings_sha256": expected["embeddings_sha256"],
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
