"""Immutable checks for the N019 Unit HiFi-GAN training recipe."""

from __future__ import annotations

from pathlib import Path

import torch

from n019.hifigan import FEATURE_MATCHING_SCALE, feature_matching_loss
from n019.manifest import sha256_file


RECIPE_VERSION = "n019-unit-hifigan-reference-v2"
EXPECTED_FEATURE_MATCHING_SCALE = 2.0
EXPECTED_MEL_LOSS_WEIGHT = 45.0


def feature_matching_probe() -> float:
    """Return the loss for hand-computable unit feature maps."""
    real = [[torch.zeros(1), torch.ones(1)]]
    generated = [[torch.ones(1), torch.zeros(1)]]
    return float(feature_matching_loss(real, generated))


def validate_feature_matching_recipe() -> None:
    """Fail closed if the deployed loss no longer matches the reference."""
    if FEATURE_MATCHING_SCALE != EXPECTED_FEATURE_MATCHING_SCALE:
        raise RuntimeError(
            "Feature-matching scale is "
            f"{FEATURE_MATCHING_SCALE}, expected "
            f"{EXPECTED_FEATURE_MATCHING_SCALE}"
        )
    probe = feature_matching_probe()
    expected = 2.0 * EXPECTED_FEATURE_MATCHING_SCALE
    if abs(probe - expected) > 1e-7:
        raise RuntimeError(
            f"Feature-matching probe returned {probe}, expected {expected}"
        )


def training_recipe_metadata() -> dict:
    """Return provenance written into new checkpoints and run metadata."""
    hifigan_path = Path(__file__).with_name("hifigan.py")
    recipe_path = Path(__file__).with_name("training_recipe.py")
    return {
        "version": RECIPE_VERSION,
        "feature_matching_scale": FEATURE_MATCHING_SCALE,
        "feature_matching_probe": feature_matching_probe(),
        "mel_loss_weight": EXPECTED_MEL_LOSS_WEIGHT,
        "hifigan_py_sha256": sha256_file(hifigan_path),
        "training_recipe_py_sha256": sha256_file(recipe_path),
    }
