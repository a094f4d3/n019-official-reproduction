"""Rewrite absolute path prefixes in one or more JSONL files."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


def rewrite(value, old: str, new: str):
    if isinstance(value, str):
        return value.replace(old, new)
    if isinstance(value, list):
        return [rewrite(item, old, new) for item in value]
    if isinstance(value, dict):
        return {key: rewrite(item, old, new) for key, item in value.items()}
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+")
    parser.add_argument("--old-root", required=True)
    parser.add_argument("--new-root", required=True)
    args = parser.parse_args()

    for raw_path in args.paths:
        path = Path(raw_path)
        rows = [
            json.loads(line)
            for line in path.read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
        updated = [rewrite(row, args.old_root, args.new_root) for row in rows]
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_text(
            "".join(
                json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n"
                for row in updated
            ),
            encoding="utf-8",
        )
        os.replace(temporary, path)
        serialized = path.read_text(encoding="utf-8")
        if args.old_root in serialized:
            raise SystemExit(f"Old root remains in {path}")
        print(f"rewritten={path} rows={len(updated)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
