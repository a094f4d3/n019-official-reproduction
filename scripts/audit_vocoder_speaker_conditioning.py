#!/usr/bin/env python3
"""Report how strongly a Unit HiFi-GAN front end weights speaker input."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch

from n019.vocoder import load_generator


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--out", required=True)
    return parser.parse_args()


def l2(tensor: torch.Tensor) -> float:
    return float(torch.linalg.vector_norm(tensor.float()).item())


def main() -> int:
    args = parse_args()
    generator, checkpoint = load_generator(args.checkpoint, torch.device("cpu"))
    weight = generator.generator.conv_pre.weight.detach()
    unit_dim = int(generator.unit_embedding.embedding_dim)
    speaker_dim = int(generator.speaker_dim)
    if weight.shape[1] != unit_dim + speaker_dim:
        raise RuntimeError(
            f"Unexpected conv_pre input channels: {weight.shape[1]}"
        )
    unit_weight = weight[:, :unit_dim, :]
    speaker_weight = weight[:, unit_dim:, :]
    result = {
        "checkpoint": str(Path(args.checkpoint).resolve()),
        "checkpoint_step": checkpoint.get("step"),
        "unit_dim": unit_dim,
        "speaker_dim": speaker_dim,
        "conv_pre_weight_l2": l2(weight),
        "unit_weight_l2": l2(unit_weight),
        "speaker_weight_l2": l2(speaker_weight),
        "unit_weight_rms": float(unit_weight.float().pow(2).mean().sqrt()),
        "speaker_weight_rms": float(speaker_weight.float().pow(2).mean().sqrt()),
        "unit_embedding_l2": l2(generator.unit_embedding.weight),
    }
    result["speaker_to_unit_weight_rms_ratio"] = (
        result["speaker_weight_rms"] / result["unit_weight_rms"]
    )
    output = Path(args.out)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
