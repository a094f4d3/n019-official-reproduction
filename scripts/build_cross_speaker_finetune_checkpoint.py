"""Build a full-state checkpoint for bounded speaker-swap fine-tuning.

The generator is replaced by a separately selected compact checkpoint. The
discriminator and discriminator optimizer stay in their trained state, while
the generator optimizer is reset for the new low-LR fine-tuning phase.
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import asdict
from pathlib import Path

import torch

from n019.hifigan import GeneratorConfig, UnitSpeakerHiFiGAN
from n019.manifest import sha256_file
from n019.vocoder import UnitVocoderConfig


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--full-state", required=True)
    parser.add_argument("--full-state-sha256", required=True)
    parser.add_argument("--generator", required=True)
    parser.add_argument("--generator-sha256", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--lr", type=float, default=5e-5)
    parser.add_argument("--speaker-swap-probability", type=float, default=0.5)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    full_state_path = Path(args.full_state)
    generator_path = Path(args.generator)
    actual_full_state_sha = sha256_file(full_state_path)
    if actual_full_state_sha != args.full_state_sha256:
        raise RuntimeError(
            f"Full-state SHA256 mismatch: {actual_full_state_sha}"
        )
    actual_generator_sha = sha256_file(generator_path)
    if actual_generator_sha != args.generator_sha256:
        raise RuntimeError(
            f"Generator SHA256 mismatch: {actual_generator_sha}"
        )
    if not 0.0 < args.lr < 2e-4:
        raise RuntimeError("Fine-tuning lr must be positive and below 2e-4")
    if not 0.0 <= args.speaker_swap_probability <= 1.0:
        raise RuntimeError("speaker swap probability must be in [0, 1]")

    full_state = torch.load(
        full_state_path,
        map_location="cpu",
        weights_only=False,
        mmap=True,
    )
    generator = torch.load(
        generator_path,
        map_location="cpu",
        weights_only=False,
        mmap=True,
    )
    raw_config = dict(full_state["config"])
    raw_config["generator"] = GeneratorConfig(**raw_config["generator"])
    config = UnitVocoderConfig(**raw_config)
    architecture_keys = (
        "vocabulary_size",
        "padding_unit_id",
        "unit_embedding_dim",
        "speaker_dim",
        "speaker_projection_dim",
        "generator",
    )
    for key in architecture_keys:
        if full_state["config"].get(key) != generator["config"].get(key):
            raise RuntimeError(f"Generator architecture mismatch for {key}")
    if set(full_state["generator"]) != set(generator["generator"]):
        raise RuntimeError("Generator state keys differ")
    for key, value in full_state["generator"].items():
        if value.shape != generator["generator"][key].shape:
            raise RuntimeError(f"Generator tensor shape mismatch for {key}")

    model = UnitSpeakerHiFiGAN(
        vocab_size=config.vocabulary_size,
        unit_embedding_dim=config.unit_embedding_dim,
        speaker_dim=config.speaker_dim,
        speaker_projection_dim=config.speaker_projection_dim,
        generator_config=config.generator,
        padding_idx=config.padding_unit_id,
    )
    optimizer_g = torch.optim.AdamW(
        model.parameters(),
        lr=args.lr,
        betas=(config.adam_beta1, config.adam_beta2),
    )
    optimizer_d = full_state["optimizer_d"]
    for group in optimizer_d["param_groups"]:
        group["lr"] = args.lr

    updated_config = asdict(config)
    updated_config["learning_rate"] = args.lr
    updated_config["speaker_swap_probability"] = (
        args.speaker_swap_probability
    )
    updated = dict(full_state)
    updated.update(
        {
            "config": updated_config,
            "generator": generator["generator"],
            "optimizer_g": optimizer_g.state_dict(),
            "scheduler_g": None,
            "scheduler_d": None,
            "step": 0,
            "epoch": 0,
            "best_validation_mel_l1": None,
            "best_validation_step": 0,
            "validations_without_improvement": 0,
            "stop_reason": None,
            "selection_policy": "mos_offline",
            "cross_speaker_initialization": {
                "full_state": str(full_state_path.resolve()),
                "full_state_sha256": actual_full_state_sha,
                "generator": str(generator_path.resolve()),
                "generator_sha256": actual_generator_sha,
                "lr": args.lr,
                "speaker_swap_probability": args.speaker_swap_probability,
            },
        }
    )
    destination = Path(args.out)
    if args.dry_run:
        print(
            json.dumps(
                {
                    "dry_run": True,
                    "out": str(destination),
                    "full_state_sha256": actual_full_state_sha,
                    "generator_sha256": actual_generator_sha,
                    "lr": args.lr,
                    "speaker_swap_probability": (
                        args.speaker_swap_probability
                    ),
                },
                indent=2,
            )
        )
        return 0
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        raise FileExistsError(destination)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    torch.save(updated, temporary)
    os.replace(temporary, destination)
    print(
        json.dumps(
            {
                "out": str(destination),
                "sha256": sha256_file(destination),
                "full_state_sha256": actual_full_state_sha,
                "generator_sha256": actual_generator_sha,
                "lr": args.lr,
                "speaker_swap_probability": args.speaker_swap_probability,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
