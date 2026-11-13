#!/usr/bin/env python3
"""Rewrite per-account audio/code paths in a JSONL unit-record manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--old-root", required=True)
    parser.add_argument("--new-root", required=True)
    parser.add_argument("--require-audio", action="store_true")
    args = parser.parse_args()

    if args.output.exists():
        raise SystemExit(f"Output already exists: {args.output}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    rows = 0
    rewritten = 0
    missing: list[str] = []
    with args.input.open(encoding="utf-8") as source, args.output.open(
        "w",
        encoding="utf-8",
    ) as destination:
        for raw in source:
            if not raw.strip():
                continue
            row = json.loads(raw)
            for field in ("audio", "codes_path", "kmeans_codebook"):
                value = str(row.get(field, ""))
                if value.startswith(args.old_root):
                    row[field] = args.new_root + value[len(args.old_root) :]
                    rewritten += 1
            if args.require_audio and not Path(row["audio"]).is_file():
                missing.append(str(row["audio"]))
            destination.write(json.dumps(row, sort_keys=True) + "\n")
            rows += 1
    if missing:
        raise SystemExit(
            f"Missing {len(missing)} audio files; first={missing[0]}"
        )
    print(
        json.dumps(
            {
                "rows": rows,
                "rewritten_fields": rewritten,
                "old_root": args.old_root,
                "new_root": args.new_root,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
