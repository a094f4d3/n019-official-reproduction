#!/usr/bin/env python3
"""Atomically rewrite one account's absolute prefix in JSONL manifests."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def rewrite_jsonl(path: Path, old: str, new: str, dry_run: bool) -> dict[str, object]:
    if not path.is_file():
        raise FileNotFoundError(path)

    before_sha256 = sha256_file(path)
    rows = 0
    replacements = 0
    temporary = path.with_name(f"{path.name}.relocate.tmp")

    with path.open("r", encoding="utf-8", newline="") as source:
        with temporary.open("w", encoding="utf-8", newline="") as destination:
            for line in source:
                rows += 1
                replacements += line.count(old)
                json.loads(line)
                rewritten = line.replace(old, new)
                json.loads(rewritten)
                destination.write(rewritten)
            destination.flush()
            os.fsync(destination.fileno())

    if dry_run or replacements == 0:
        temporary.unlink(missing_ok=True)
    else:
        backup = path.with_name(f"{path.name}.pre-relocate.bak")
        if not backup.exists():
            shutil.copy2(path, backup)
        os.chmod(temporary, path.stat().st_mode)
        os.replace(temporary, path)

    after_sha256 = sha256_file(path)
    remaining = sum(
        1 for line in path.open("r", encoding="utf-8") if old in line
    )
    return {
        "path": str(path),
        "rows": rows,
        "replacements": replacements,
        "remaining_old_prefix_rows": remaining,
        "before_sha256": before_sha256,
        "after_sha256": after_sha256,
        "changed": bool(replacements and not dry_run),
        "dry_run": dry_run,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", type=Path, action="append", required=True)
    parser.add_argument("--old-account", required=True)
    parser.add_argument("--new-account", required=True)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    old = f"/public/home/{args.old_account}/"
    new = f"/public/home/{args.new_account}/"
    if args.old_account == args.new_account:
        raise SystemExit("--old-account and --new-account must differ")

    for path in args.path:
        summary = rewrite_jsonl(path, old, new, args.dry_run)
        print(json.dumps(summary, ensure_ascii=True, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
