"""Export only tensors changed relative to a base SafeTensors checkpoint."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import torch
from safetensors.torch import load_file


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    base = load_file(str(args.base), device="cpu")
    model = load_file(str(args.model), device="cpu")
    deltas: dict[str, torch.Tensor] = {}
    extras: dict[str, torch.Tensor] = {}
    for key, value in model.items():
        reference = base.get(key)
        if reference is None:
            extras[key] = value
            continue
        if reference.shape != value.shape:
            raise ValueError(f"Shape mismatch for {key}: {reference.shape} vs {value.shape}")
        difference = value.to(torch.float32) - reference.to(torch.float32)
        if torch.count_nonzero(difference).item():
            deltas[key] = difference.to(torch.float16)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    torch.save(
        {
            "base_sha256": sha256(args.base),
            "model_sha256": sha256(args.model),
            "delta_tensors": deltas,
            "extra_tensors": extras,
        },
        args.out,
    )
    print(
        f"wrote={args.out} deltas={len(deltas)} extras={len(extras)} "
        f"bytes={args.out.stat().st_size}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
