#!/usr/bin/env python3
"""Merge W-NT attack summaries without silently replacing duplicate scores."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path


ATTACK_ORDER = ("I", "L", "S")
METRIC_KEYS = (
    "female_eer_percent",
    "male_eer_percent",
    "mean_eer_percent",
)


def _validated_attack(attack: str, metrics: dict) -> dict:
    values = {}
    for key in METRIC_KEYS:
        if key not in metrics:
            raise ValueError(f"Attack {attack} is missing {key}")
        value = float(metrics[key])
        if not math.isfinite(value):
            raise ValueError(f"Attack {attack} has non-finite {key}")
        values[key] = value
    expected_mean = (values["female_eer_percent"] + values["male_eer_percent"]) / 2
    if not math.isclose(
        values["mean_eer_percent"],
        expected_mean,
        rel_tol=0.0,
        abs_tol=1e-6,
    ):
        raise ValueError(
            f"Attack {attack} mean does not equal the female/male mean"
        )
    return values


def merge_summaries(paths: list[Path], required: list[str]) -> dict:
    attacks: dict[str, dict] = {}
    suffixes: list[str] = []
    sources: list[str] = []
    for path in paths:
        data = json.loads(path.read_text(encoding="utf-8"))
        incoming = data.get("attacks")
        if not isinstance(incoming, dict):
            raise ValueError(f"{path} has no attacks object")
        source = str(path.resolve())
        sources.append(source)
        suffix = data.get("suffix")
        if isinstance(suffix, str) and suffix and suffix not in suffixes:
            suffixes.append(suffix)
        for attack, metrics in incoming.items():
            normalized = _validated_attack(str(attack), metrics)
            if attack in attacks and attacks[attack] != normalized:
                raise ValueError(f"Conflicting scores for attack {attack}")
            attacks[attack] = normalized

    missing = [attack for attack in required if attack not in attacks]
    if missing:
        raise ValueError(f"Missing required attacks: {' '.join(missing)}")
    ordered = {
        attack: attacks[attack]
        for attack in ATTACK_ORDER
        if attack in attacks
    }
    ordered.update(
        sorted(
            (attack, metrics)
            for attack, metrics in attacks.items()
            if attack not in ordered
        )
    )
    return {
        "attacks": ordered,
        "suffixes": suffixes,
        "sources": sources,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Merge one or more W-NT attack summary.json files."
    )
    parser.add_argument("--summary", action="append", required=True, type=Path)
    parser.add_argument(
        "--require",
        nargs="+",
        choices=ATTACK_ORDER,
        default=list(ATTACK_ORDER),
    )
    parser.add_argument("--out", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    merged = merge_summaries(args.summary, list(args.require))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(merged, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(merged, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
