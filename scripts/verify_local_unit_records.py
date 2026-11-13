#!/usr/bin/env python3
"""Verify that unit-record paths belong to the current account and exist."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def verify_records(
    records: Path,
    root: Path,
    fields: tuple[str, ...],
    allowed_roots: tuple[Path, ...] = (),
) -> dict:
    records = records.resolve()
    roots = tuple(dict.fromkeys(
        path.resolve() for path in (root, *allowed_roots)
    ))
    rows = [
        json.loads(line)
        for line in records.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    missing: list[str] = []
    outside: list[str] = []
    for row in rows:
        for field in fields:
            raw = row.get(field)
            if not raw:
                missing.append(f"{field}: missing field")
                continue
            path = Path(raw).resolve()
            if not any(path.is_relative_to(candidate) for candidate in roots):
                outside.append(f"{field}: {path}")
            elif not path.is_file():
                missing.append(f"{field}: {path}")
    result = {
        "records": len(rows),
        "roots": [str(path) for path in roots],
        "fields": list(fields),
        "missing": len(missing),
        "outside_root": len(outside),
        "missing_examples": missing[:5],
        "outside_examples": outside[:5],
    }
    if missing or outside:
        raise ValueError(json.dumps(result, indent=2, sort_keys=True))
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--records", required=True, type=Path)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument(
        "--allow-root",
        action="append",
        type=Path,
        default=[],
        help="Additional read-only root, e.g. a shared data owner's home.",
    )
    parser.add_argument(
        "--fields",
        default="audio,codes_path,kmeans_codebook",
        help="Comma-separated unit-record path fields.",
    )
    args = parser.parse_args()
    fields = tuple(field.strip() for field in args.fields.split(",") if field.strip())
    print(
        json.dumps(
            verify_records(
                args.records,
                args.root,
                fields,
                tuple(args.allow_root),
            ),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
