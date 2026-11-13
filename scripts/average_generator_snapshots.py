"""Average generator-only snapshots into a single SWA-style checkpoint."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--snapshots", nargs="+", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    paths = [Path(item) for item in args.snapshots]
    if len(paths) < 2:
        raise SystemExit("need at least two snapshots to average")

    base = torch.load(paths[0], map_location="cpu", weights_only=False)
    base_state = base["generator"]
    keys = list(base_state.keys())
    averaged = {key: torch.zeros_like(base_state[key]) for key in keys}

    for path in paths:
        checkpoint = torch.load(path, map_location="cpu", weights_only=False)
        state = checkpoint["generator"]
        if list(state.keys()) != keys:
            raise SystemExit(f"state dict keys differ: {path}")
        for key in keys:
            if state[key].shape != base_state[key].shape:
                raise SystemExit(f"shape mismatch for {key}: {path}")
        for key in keys:
            averaged[key].add_(state[key].to(torch.float32))

    count = float(len(paths))
    for key in keys:
        averaged[key].div_(count)
        averaged[key] = averaged[key].to(base_state[key].dtype)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    torch.save(
        {
            "generator": averaged,
            "config": base["config"],
            "recipe": base.get("recipe"),
            "step": base.get("step"),
            "averaged_from": [str(path) for path in paths],
        },
        out,
    )
    print(
        json.dumps(
            {
                "out": str(out),
                "count": len(paths),
                "sources": [str(path) for path in paths],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
