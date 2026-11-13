#!/usr/bin/env python3
"""Verify an extracted vocoder-selection subset against its transfer manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--limit", type=int, default=100)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if int(manifest["rows"]) != args.limit:
        raise SystemExit(
            f"Transfer manifest declares {manifest['rows']} rows, need {args.limit}"
        )
    failures = []
    for entry in manifest["files"]:
        target = Path(entry["target"])
        if not target.is_file():
            failures.append(f"missing {target}")
            continue
        if target.stat().st_size != int(entry["bytes"]):
            failures.append(f"size mismatch {target}")
            continue
        if sha256(target) != entry["sha256"]:
            failures.append(f"sha256 mismatch {target}")
    if failures:
        raise SystemExit("\n".join(failures[:20]))

    root = args.manifest.parent
    unit_rows = [
        line
        for line in (root / "unit_records.jsonl")
        .read_text(encoding="utf-8")
        .splitlines()
        if line.strip()
    ]
    source_rows = [
        line
        for line in (root / "manifest.jsonl")
        .read_text(encoding="utf-8")
        .splitlines()
        if line.strip()
    ]
    if len(unit_rows) != args.limit or len(source_rows) != args.limit:
        raise SystemExit(
            f"Expected {args.limit} manifest/unit rows, got "
            f"{len(source_rows)}/{len(unit_rows)}"
        )
    print(
        json.dumps(
            {
                "status": "ok",
                "rows": args.limit,
                "speakers": int(manifest["speakers"]),
                "verified_files": len(manifest["files"]),
                "total_bytes": int(manifest["total_bytes"]),
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
