"""Remove optional extensions absent from the fairseq 0.12.2 PyPI sdist."""

from __future__ import annotations

import argparse
from pathlib import Path


def patch_setup_source(source: str) -> str:
    marker = "    extensions.extend("
    if source.count(marker) != 3:
        raise ValueError(
            "Expected three extensions.extend blocks in fairseq setup.py"
        )
    start = source.index(marker)
    end_marker = '    if "CUDA_HOME" in os.environ:\n'
    end = source.index(end_marker, start)
    patched = (
        source[:start]
        + "    # Optional C++ extensions are absent from the PyPI sdist.\n"
        + source[end:]
    )
    if patched.count(marker) != 1:
        raise ValueError("CPU optional extension blocks were not fully removed")
    return patched


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--setup", required=True)
    args = parser.parse_args()
    path = Path(args.setup).resolve()
    source = path.read_text(encoding="utf-8")
    backup = path.with_suffix(".py.n019.bak")
    if not backup.exists():
        backup.write_text(source, encoding="utf-8")
    path.write_text(patch_setup_source(source), encoding="utf-8")
    print(f"PATCHED_FAIRSEQ_SDIST setup={path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
