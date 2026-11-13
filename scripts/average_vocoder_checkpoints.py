"""Average compatible compact generator checkpoints for an offline screen."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

import torch


ARCHITECTURE_KEYS = (
    "vocabulary_size",
    "padding_unit_id",
    "unit_embedding_dim",
    "speaker_dim",
    "speaker_projection_dim",
    "generator",
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_checkpoint(path: Path) -> dict:
    try:
        return torch.load(
            path,
            map_location="cpu",
            mmap=True,
            weights_only=False,
        )
    except TypeError:
        return torch.load(path, map_location="cpu", weights_only=False)


def checkpoint_configs_compatible(
    first: dict | None,
    other: dict | None,
    *,
    allow_nonarchitectural_diff: bool,
) -> bool:
    if not allow_nonarchitectural_diff:
        return other == first
    if first is None or other is None:
        return False
    return all(other.get(key) == first.get(key) for key in ARCHITECTURE_KEYS)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", type=Path, action="append", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument(
        "--weight",
        type=float,
        action="append",
        default=None,
        help="Optional per-checkpoint weight; must match checkpoint count.",
    )
    parser.add_argument(
        "--effective-weight-norm",
        action="store_true",
        help=(
            "Average reconstructed weight-normalised kernels instead of "
            "averaging the original g/v parameters independently."
        ),
    )
    parser.add_argument(
        "--allow-nonarchitectural-config-diff",
        action="store_true",
        help=(
            "Allow run-control fields such as max_hours to differ while "
            "requiring identical generator architecture and training recipe."
        ),
    )
    args = parser.parse_args()

    if len(args.checkpoint) < 2:
        raise ValueError("At least two checkpoints are required")
    weights = args.weight or [1.0] * len(args.checkpoint)
    if len(weights) != len(args.checkpoint):
        raise ValueError("Checkpoint and weight counts differ")
    if any(weight <= 0.0 for weight in weights):
        raise ValueError("Weights must be positive")
    weight_sum = sum(weights)
    weights = [weight / weight_sum for weight in weights]

    checkpoints = [load_checkpoint(path) for path in args.checkpoint]
    first = checkpoints[0]
    config = first.get("config")
    recipe = first.get("recipe")
    for path, checkpoint in zip(args.checkpoint, checkpoints):
        if not checkpoint_configs_compatible(
            config,
            checkpoint.get("config"),
            allow_nonarchitectural_diff=args.allow_nonarchitectural_config_diff,
        ):
            raise ValueError(f"Architecture mismatch: {path}")
        if checkpoint.get("recipe") != recipe:
            raise ValueError(f"Training recipe mismatch: {path}")
    states = [checkpoint["generator"] for checkpoint in checkpoints]
    keys = states[0].keys()
    expected_keys = set(keys)
    for path, state in zip(args.checkpoint[1:], states[1:]):
        if set(state) != expected_keys:
            raise ValueError(f"Generator state key mismatch: {path}")
    averaged = {}
    skip = set()
    if args.effective_weight_norm:
        suffixes = (
            ".parametrizations.weight.original0",
            ".parametrizations.weight.original1",
        )
        for key in keys:
            if not key.endswith(suffixes[1]):
                continue
            g_key = key[: -len(suffixes[1])] + suffixes[0]
            if g_key not in states[0]:
                raise KeyError(f"Missing weight-normalisation scale: {g_key}")
            effective = []
            for state in states:
                g = state[g_key].float()
                v = state[key].float()
                norm = torch.linalg.vector_norm(
                    v,
                    dim=tuple(range(1, v.ndim)),
                    keepdim=True,
                ).clamp_min(1e-12)
                effective.append(v * (g / norm))
            accumulated = effective[0] * weights[0]
            for weight, value in zip(weights[1:], effective[1:]):
                accumulated.add_(value, alpha=weight)
            norm = torch.linalg.vector_norm(
                accumulated,
                dim=tuple(range(1, accumulated.ndim)),
                keepdim=True,
            ).clamp_min(1e-12)
            averaged[key] = (accumulated / norm).to(states[0][key].dtype)
            averaged[g_key] = norm.to(states[0][g_key].dtype)
            skip.update((key, g_key))
    for key in keys:
        if key in skip:
            continue
        first_value = states[0][key]
        if not torch.is_floating_point(first_value):
            averaged[key] = first_value.clone()
            continue
        accumulated = first_value.float() * weights[0]
        for weight, state in zip(weights[1:], states[1:]):
            value = state[key]
            if value.shape != first_value.shape:
                raise ValueError(f"Tensor shape mismatch for {key}")
            accumulated.add_(value.float(), alpha=weight)
        averaged[key] = accumulated.to(first_value.dtype)

    payload = {
        "config": config,
        "generator": averaged,
        "step": max(
            int(checkpoint.get("step", 0)) for checkpoint in checkpoints
        ),
        "epoch": max(
            int(checkpoint.get("epoch", 0)) for checkpoint in checkpoints
        ),
        "validation_mel_l1": float("nan"),
        "selection_policy": "offline_model_average",
        "average_effective_weight_norm": args.effective_weight_norm,
        "allow_nonarchitectural_config_diff": (
            args.allow_nonarchitectural_config_diff
        ),
        "recipe": recipe,
        "average_source": [
            {
                "path": str(path.resolve()),
                "sha256": sha256_file(path),
                "weight": weight,
                "step": int(checkpoint.get("step", 0)),
            }
            for path, checkpoint, weight in zip(
                args.checkpoint, checkpoints, weights
            )
        ],
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.out.with_suffix(args.out.suffix + ".tmp")
    torch.save(payload, temporary)
    os.replace(temporary, args.out)
    print(
        json.dumps(
            {
                "out": str(args.out.resolve()),
                "sha256": sha256_file(args.out),
                "sources": payload["average_source"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
