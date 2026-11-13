"""Apply the minimal Python 3.11 dataclass fix required by fairseq 0.12.2."""

from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path


PATTERN = re.compile(
    r"^(?P<indent>[ \t]+)(?P<name>[A-Za-z_]\w*): "
    r"(?P<type>[A-Za-z_]\w*) = (?P=type)\(\)$",
    re.MULTILINE,
)
FIELD_PATTERN = re.compile(
    r"field\(default=(?P<type>[A-Za-z_]\w*)\(\)\)",
)
INIT_OLD = """\
    for k in FairseqConfig.__dataclass_fields__:
        v = FairseqConfig.__dataclass_fields__[k].default
"""
INIT_NEW = """\
    for k, fairseq_field in FairseqConfig.__dataclass_fields__.items():
        if fairseq_field.default_factory is not MISSING:
            v = fairseq_field.default_factory()
        else:
            v = fairseq_field.default
"""


def patch_source(source: str) -> tuple[str, int]:
    class_match = re.search(
        r"^class FairseqConfig\(FairseqDataclass\):\n",
        source,
        flags=re.MULTILINE,
    )
    if class_match is None:
        raise ValueError("FairseqConfig class not found")
    next_class = re.search(
        r"^class ",
        source[class_match.end() :],
        flags=re.MULTILINE,
    )
    block_end = (
        class_match.end() + next_class.start()
        if next_class is not None
        else len(source)
    )
    block = source[class_match.end() : block_end]

    def replace(match: re.Match[str]) -> str:
        return (
            f"{match.group('indent')}{match.group('name')}: "
            f"{match.group('type')} = field("
            f"default_factory={match.group('type')})"
        )

    updated, count = PATTERN.subn(replace, block)
    if count == 0:
        raise ValueError("No mutable FairseqConfig defaults found")
    return source[: class_match.end()] + updated + source[block_end:], count


def patch_module(source: str) -> tuple[str, int]:
    """Patch all capitalised dataclass defaults in one fairseq module."""

    def replace(match: re.Match[str]) -> str:
        return (
            f"{match.group('indent')}{match.group('name')}: "
            f"{match.group('type')} = field("
            f"default_factory={match.group('type')})"
        )

    updated, bare_count = PATTERN.subn(replace, source)
    updated, field_count = FIELD_PATTERN.subn(
        lambda match: f"field(default_factory={match.group('type')})",
        updated,
    )
    return updated, bare_count + field_count


def patch_initialize_source(source: str) -> tuple[str, int]:
    if INIT_NEW in source:
        return source, 0
    if INIT_OLD not in source:
        raise ValueError("fairseq initialize field loop not found")
    if "from dataclasses import MISSING" not in source:
        source = source.replace(
            "import logging\n",
            "import logging\nfrom dataclasses import MISSING\n",
            1,
        )
    return source.replace(INIT_OLD, INIT_NEW, 1), 1


def patch_tree(root: Path, *, dry_run: bool) -> tuple[int, int]:
    files = 0
    fields = 0
    for path in sorted(root.rglob("*.py")):
        source = path.read_text(encoding="utf-8")
        if path.as_posix().endswith("fairseq/dataclass/initialize.py"):
            updated, count = patch_initialize_source(source)
        else:
            updated, count = patch_module(source)
        if count == 0:
            continue
        files += 1
        fields += count
        print(f"patched_fields={count} path={path}")
        if dry_run:
            continue
        backup = path.with_suffix(path.suffix + ".n019.bak")
        if not backup.exists():
            shutil.copy2(path, backup)
        path.write_text(updated, encoding="utf-8")
    return files, fields


def main() -> int:
    parser = argparse.ArgumentParser()
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--configs")
    target.add_argument("--tree")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.tree:
        files, fields = patch_tree(Path(args.tree).resolve(), dry_run=args.dry_run)
        print(f"patched_files={files} patched_fields={fields}")
        return 0

    path = Path(args.configs).resolve()
    source = path.read_text(encoding="utf-8")
    updated, count = patch_source(source)
    print(f"patched_fields={count} path={path}")
    if not args.dry_run:
        backup = path.with_suffix(path.suffix + ".n019.bak")
        if not backup.exists():
            shutil.copy2(path, backup)
        path.write_text(updated, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
