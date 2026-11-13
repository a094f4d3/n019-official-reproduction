#!/usr/bin/env python3
"""Resample an existing target map within the opposite-gender target pool."""

from __future__ import annotations

import argparse
import json
import random
from collections import Counter
from pathlib import Path

from n019.manifest import iter_jsonl, sha256_file, write_json, write_jsonl


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Replace each row's target speaker with a deterministic uniform "
            "sample from the opposite-gender target speakers already present "
            "in the input map."
        )
    )
    parser.add_argument("--input-map", required=True)
    parser.add_argument("--speakers-file", required=True)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--source-spk2gender")
    source.add_argument("--source-speakers-file")
    parser.add_argument("--output-map", required=True)
    parser.add_argument("--report", default=None)
    parser.add_argument("--seed", type=int, default=20261102)
    return parser.parse_args()


def read_libritts_speakers(path: str | Path) -> dict[str, str]:
    genders: dict[str, str] = {}
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        fields = [field.strip() for field in line.split("|")]
        if len(fields) < 2 or fields[1].lower() not in {"f", "m"}:
            raise ValueError(f"Malformed LibriTTS SPEAKERS.txt row: {raw!r}")
        genders[fields[0]] = fields[1].lower()
    if not genders:
        raise ValueError(f"No speaker genders found in {path}")
    return genders


def read_spk2gender(path: str | Path) -> dict[str, str]:
    genders: dict[str, str] = {}
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line:
            continue
        fields = line.split()
        if len(fields) != 2 or fields[1].lower() not in {"f", "m"}:
            raise ValueError(f"Malformed spk2gender row: {raw!r}")
        genders[fields[0]] = fields[1].lower()
    if not genders:
        raise ValueError(f"No speaker genders found in {path}")
    return genders


def main() -> int:
    args = parse_args()
    rows = list(iter_jsonl(args.input_map))
    if not rows:
        raise ValueError("Input target map is empty")

    target_genders = read_libritts_speakers(args.speakers_file)
    if args.source_spk2gender:
        source_genders = read_spk2gender(args.source_spk2gender)
        source_gender_path = args.source_spk2gender
    else:
        source_genders = read_libritts_speakers(args.source_speakers_file)
        source_gender_path = args.source_speakers_file
    target_speakers = sorted({str(row["target_speaker"]) for row in rows})
    missing_targets = [speaker for speaker in target_speakers if speaker not in target_genders]
    if missing_targets:
        raise KeyError(
            f"Missing gender for {len(missing_targets)} target speakers; "
            f"first={missing_targets[:5]}"
        )
    pools = {
        gender: [
            speaker
            for speaker in target_speakers
            if target_genders[speaker] == gender
        ]
        for gender in ("f", "m")
    }
    if not pools["f"] or not pools["m"]:
        raise ValueError(f"Target pool does not contain both genders: {pools}")

    rng = random.Random(args.seed)
    output_rows: list[dict] = []
    pair_counts: Counter[tuple[str, str]] = Counter()
    missing_sources = 0
    for row in rows:
        source_speaker = str(row["source_speaker"])
        source_gender = source_genders.get(source_speaker)
        if source_gender is None:
            missing_sources += 1
            raise KeyError(f"Missing source gender for speaker {source_speaker}")
        target_gender = "m" if source_gender == "f" else "f"
        target_speaker = rng.choice(pools[target_gender])
        output = dict(row)
        output["target_speaker"] = target_speaker
        output["target_id"] = target_speaker
        sampling_metadata = {
            "sampling": "opposite_gender_uniform_speaker",
            "source_gender": source_gender,
            "target_gender": target_gender,
            "seed": args.seed,
        }
        output["sampling"] = sampling_metadata
        output_rows.append(output)
        pair_counts[(source_gender, target_gender)] += 1

    write_jsonl(args.output_map, output_rows)
    report_path = (
        Path(args.report)
        if args.report
        else Path(args.output_map).with_suffix(".report.json")
    )
    report = {
        "method": "opposite_gender_uniform_speaker",
        "seed": args.seed,
        "input_rows": len(rows),
        "output_rows": len(output_rows),
        "source_speakers": len({str(row["source_speaker"]) for row in rows}),
        "target_speakers": len(target_speakers),
        "target_pool_sizes": {gender: len(pool) for gender, pool in pools.items()},
        "pair_counts": {
            f"{source}_to_{target}": count
            for (source, target), count in sorted(pair_counts.items())
        },
        "missing_source_genders": missing_sources,
        "input_map": str(Path(args.input_map).resolve()),
        "input_map_sha256": sha256_file(args.input_map),
        "speakers_file": str(Path(args.speakers_file).resolve()),
        "speakers_file_sha256": sha256_file(args.speakers_file),
        "source_gender_file": str(Path(source_gender_path).resolve()),
        "source_gender_file_sha256": sha256_file(source_gender_path),
        "output_map": str(Path(args.output_map).resolve()),
        "output_map_sha256": sha256_file(args.output_map),
    }
    write_json(report_path, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
