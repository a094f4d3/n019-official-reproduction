"""Extract the generator from a full vocoder last.pt for read-only diagnostics."""

from __future__ import annotations

import argparse
from pathlib import Path

import torch


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    checkpoint = torch.load(args.source, map_location="cpu", weights_only=False)
    compact = {
        key: checkpoint[key]
        for key in (
            "config",
            "generator",
            "step",
            "epoch",
            "validation_mel_l1",
            "validation_step",
            "stop_reason",
        )
        if key in checkpoint
    }
    compact["diagnostic_source"] = str(args.source)
    compact["diagnostic_note"] = (
        "Generator-only diagnostic extraction; not an official replacement."
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.out.with_suffix(args.out.suffix + ".tmp")
    torch.save(compact, temporary)
    temporary.replace(args.out)
    print(
        f"WROTE {args.out} bytes={args.out.stat().st_size} "
        f"step={compact.get('step')}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
