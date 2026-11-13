"""Relocate absolute unit-record paths after cross-account transfer."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


PATH_FIELDS = ("audio", "codes_path", "kmeans_codebook")


def relocate_rows(
    rows: list[dict],
    *,
    old_root: Path,
    new_root: Path,
    validate: bool,
    fields: tuple[str, ...] = PATH_FIELDS,
) -> tuple[list[dict], int]:
    old_root = old_root.resolve()
    new_root = new_root.resolve()
    changed = 0
    output = []
    for row in rows:
        updated = dict(row)
        for field in fields:
            if field not in updated:
                continue
            raw = Path(updated[field])
            try:
                resolved = raw.resolve()
            except OSError as error:
                raise ValueError(f"Cannot resolve {field}: {raw}") from error
            try:
                relative = resolved.relative_to(old_root)
                destination = (new_root / relative).resolve()
            except ValueError:
                try:
                    resolved.relative_to(new_root)
                except ValueError as error:
                    raise ValueError(
                        f"{field} outside both roots: {raw} "
                        f"(old_root={old_root}, new_root={new_root})"
                    ) from error
                destination = resolved
            if validate and not destination.is_file():
                raise FileNotFoundError(f"{field}: {destination}")
            if str(destination) != str(resolved):
                changed += 1
            updated[field] = str(destination)
        output.append(updated)
    return output, changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--records", required=True)
    parser.add_argument("--old-root", required=True)
    parser.add_argument("--new-root", required=True)
    parser.add_argument(
        "--fields",
        default=",".join(PATH_FIELDS),
        help="Comma-separated path fields to relocate.",
    )
    parser.add_argument("--no-validate", action="store_true")
    args = parser.parse_args()
    path = Path(args.records).resolve()
    rows = [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if not rows:
        raise ValueError("Unit record file is empty")
    relocated, changed = relocate_rows(
        rows,
        old_root=Path(args.old_root),
        new_root=Path(args.new_root),
        validate=not args.no_validate,
        fields=tuple(
            field.strip() for field in args.fields.split(",") if field.strip()
        ),
    )
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as handle:
        for row in relocated:
            handle.write(json.dumps(row, ensure_ascii=True) + "\n")
    os.replace(temporary, path)
    print(f"records={len(relocated)} changed={changed} path={path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
