#!/usr/bin/env python3
"""Rewrite a JSONL unit-record path prefix and verify the localized files."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


PATH_FIELDS = (
    "audio",
    "codes_path",
    "kmeans_codebook",
    "original_codes_path",
    "original_kmeans_codebook",
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--old-prefix", required=True)
    parser.add_argument("--new-prefix", required=True)
    parser.add_argument("--expected-rows", type=int, required=True)
    args = parser.parse_args()

    source = Path(args.input)
    destination = Path(args.output)
    destination.parent.mkdir(parents=True, exist_ok=True)

    rows = 0
    rewritten = 0
    checked = 0
    with source.open(encoding="utf-8") as reader, destination.open(
        "w", encoding="utf-8"
    ) as writer:
        for line_number, line in enumerate(reader, start=1):
            if not line.strip():
                continue
            row = json.loads(line)
            for field in PATH_FIELDS:
                value = row.get(field)
                if not isinstance(value, str):
                    continue
                if value.startswith(args.old_prefix):
                    value = args.new_prefix + value[len(args.old_prefix) :]
                    row[field] = value
                    rewritten += 1
                if field in {"audio", "codes_path", "kmeans_codebook"}:
                    path = Path(value)
                    if not path.is_file():
                        raise FileNotFoundError(
                            f"row {line_number}: missing localized {field}: {path}"
                        )
                    checked += 1
            writer.write(json.dumps(row, sort_keys=True) + "\n")
            rows += 1

    if rows != args.expected_rows:
        raise ValueError(f"Expected {args.expected_rows} rows, got {rows}")
    if rewritten == 0:
        raise ValueError("No path fields matched --old-prefix")

    print(
        json.dumps(
            {
                "input": str(source),
                "input_sha256": sha256_file(source),
                "output": str(destination),
                "output_sha256": sha256_file(destination),
                "rows": rows,
                "rewritten_path_fields": rewritten,
                "checked_local_files": checked,
                "old_prefix": args.old_prefix,
                "new_prefix": args.new_prefix,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
