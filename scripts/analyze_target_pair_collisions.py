#!/usr/bin/env python3
"""Audit target-identity collisions in VPC enrollment/trial pairs."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


def read_jsonl(path: Path) -> list[dict]:
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def read_wav_scp(path: Path) -> dict[str, str]:
    rows: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        identifier, audio = line.split(maxsplit=1)
        if identifier in rows:
            raise ValueError(f"Duplicate wav.scp id: {identifier}")
        rows[identifier] = audio
    return rows


def ratio(numerator: int, denominator: int) -> float | None:
    return numerator / denominator if denominator else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-map", action="append", required=True)
    parser.add_argument("--vpc-data", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    vpc_root = Path(args.vpc_data)
    results = {}
    for target_map_arg in args.target_map:
        target_map_path = Path(target_map_arg)
        mappings = read_jsonl(target_map_path)
        target_speaker = {
            str(row["source_id"]): str(row["target_speaker"]) for row in mappings
        }
        if len(target_speaker) != len(mappings):
            raise ValueError(f"Duplicate source IDs in {target_map_path}")

        attacks = {}
        for gender, split in (("female", "f"), ("male", "m")):
            enroll_scp_path = vpc_root / f"libri_test_enrolls/wav.scp"
            trials_path = vpc_root / f"libri_test_trials_{split}/trials"
            enroll_scp = read_wav_scp(enroll_scp_path)
            enroll_by_speaker: dict[str, list[str]] = {}
            for identifier in enroll_scp:
                speaker = identifier.split("-", 1)[0]
                enroll_by_speaker.setdefault(speaker, []).append(identifier)

            positive_same = positive_comparisons = 0
            positive_any = positive_total = 0
            negative_same = negative_comparisons = 0
            negative_any = negative_total = 0
            pair_count = 0
            for line in trials_path.read_text(encoding="utf-8").splitlines():
                if not line.strip():
                    continue
                fields = line.split()
                if len(fields) < 2:
                    raise ValueError(f"Bad trial row: {line}")
                speaker, trial_id = fields[:2]
                enrollment_ids = enroll_by_speaker.get(speaker)
                if not enrollment_ids:
                    raise ValueError(f"No enrollment for speaker {speaker}")
                if trial_id not in target_speaker:
                    raise ValueError(f"Missing target map trial id {trial_id}")
                for enrollment_id in enrollment_ids:
                    if enrollment_id not in target_speaker:
                        raise ValueError(
                            f"Missing target map enrollment id {enrollment_id}"
                        )
                same_flags = [
                    target_speaker[enrollment_id] == target_speaker[trial_id]
                    for enrollment_id in enrollment_ids
                ]
                same_count = sum(same_flags)
                pair_count += 1
                if trial_id.startswith(speaker + "-"):
                    positive_total += 1
                    positive_comparisons += len(same_flags)
                    positive_same += same_count
                    positive_any += int(any(same_flags))
                else:
                    negative_total += 1
                    negative_comparisons += len(same_flags)
                    negative_same += same_count
                    negative_any += int(any(same_flags))

            attacks[gender] = {
                "pairs": pair_count,
                "positive_pairs": positive_total,
                "positive_same_target": positive_same,
                "positive_enrollment_comparisons": positive_comparisons,
                "positive_same_target_rate": ratio(
                    positive_same, positive_comparisons
                ),
                "positive_any_enrollment_same_target": positive_any,
                "positive_any_enrollment_same_target_rate": ratio(
                    positive_any, positive_total
                ),
                "negative_pairs": negative_total,
                "negative_same_target": negative_same,
                "negative_enrollment_comparisons": negative_comparisons,
                "negative_same_target_rate": ratio(
                    negative_same, negative_comparisons
                ),
                "negative_any_enrollment_same_target": negative_any,
                "negative_any_enrollment_same_target_rate": ratio(
                    negative_any, negative_total
                ),
            }

        target_counts = Counter(target_speaker.values())
        results[str(target_map_path.resolve())] = {
            "rows": len(mappings),
            "target_speakers": len(target_counts),
            "target_count_min": min(target_counts.values()),
            "target_count_max": max(target_counts.values()),
            "attacks": attacks,
        }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(results, indent=2, sort_keys=True) + "\n")
    print(json.dumps(results, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
