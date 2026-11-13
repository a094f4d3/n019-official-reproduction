#!/usr/bin/env python
"""Fail closed unless the deployed N019 vocoder recipe matches its lock file."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from n019.manifest import sha256_file  # noqa: E402
from n019.training_recipe import (  # noqa: E402
    EXPECTED_FEATURE_MATCHING_SCALE,
    RECIPE_VERSION,
    feature_matching_probe,
    validate_feature_matching_recipe,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--lock",
        type=Path,
        default=ROOT / "configs" / "training_recipe_lock.json",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.lock.is_file():
        raise FileNotFoundError(f"Training recipe lock not found: {args.lock}")
    lock = json.loads(args.lock.read_text(encoding="utf-8"))
    validate_feature_matching_recipe()
    if lock.get("version") != RECIPE_VERSION:
        raise RuntimeError(
            f"Recipe version mismatch: {lock.get('version')} != {RECIPE_VERSION}"
        )
    if float(lock.get("feature_matching_scale")) != EXPECTED_FEATURE_MATCHING_SCALE:
        raise RuntimeError("Recipe lock has the wrong feature-matching scale")
    probe = feature_matching_probe()
    if abs(float(lock.get("feature_matching_probe")) - probe) > 1e-7:
        raise RuntimeError(
            f"Recipe probe mismatch: {lock.get('feature_matching_probe')} != {probe}"
        )
    for relative, expected in sorted(lock["source_sha256"].items()):
        path = ROOT / relative
        actual = sha256_file(path)
        if actual != expected:
            raise RuntimeError(
                f"Training source hash mismatch for {relative}: "
                f"{actual} != {expected}"
            )
    print(
        json.dumps(
            {
                "status": "verified",
                "version": RECIPE_VERSION,
                "feature_matching_scale": EXPECTED_FEATURE_MATCHING_SCALE,
                "feature_matching_probe": probe,
                "lock": str(args.lock.resolve()),
                "lock_sha256": sha256_file(args.lock),
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
