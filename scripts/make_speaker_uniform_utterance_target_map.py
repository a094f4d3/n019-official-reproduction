#!/usr/bin/env python3
"""Sample one available target utterance per source row, uniformly by speaker."""

from __future__ import annotations

import argparse
import hashlib
import json
import random
from collections import Counter, defaultdict
from pathlib import Path
from statistics import median


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-map", required=True)
    target_group = parser.add_mutually_exclusive_group(required=True)
    target_group.add_argument("--available-target-map")
    target_group.add_argument(
        "--target-manifest",
        help=(
            "Raw LibriTTS manifest with id/audio/speaker columns. This is "
            "preferred for exact coverage of the full train-other-500 pool."
        ),
    )
    parser.add_argument("--out", required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--seed", type=int, default=20261102)
    return parser.parse_args()


def read_jsonl(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def normalize_target_rows(rows: list[dict]) -> list[dict]:
    normalized = []
    for row in rows:
        target_id = row.get("target_id", row.get("id"))
        target_speaker = row.get("target_speaker", row.get("speaker"))
        target_audio = row.get("target_audio", row.get("audio"))
        if target_id is None or target_speaker is None or target_audio is None:
            raise ValueError(
                "Target rows must provide id/audio/speaker or "
                "target_id/target_audio/target_speaker"
            )
        output = dict(row)
        output["target_id"] = str(target_id)
        output["target_speaker"] = str(target_speaker)
        output["target_audio"] = str(target_audio)
        normalized.append(output)
    return normalized


def deterministic_rng(seed: int, source_id: str) -> random.Random:
    material = f"{seed}:{source_id}".encode("utf-8")
    child_seed = int.from_bytes(hashlib.sha256(material).digest()[:8], "big")
    return random.Random(child_seed)


def unique_targets(rows: list[dict]) -> dict[str, dict]:
    targets: dict[str, dict] = {}
    for row in rows:
        target_id = str(row["target_id"])
        target_speaker = str(row["target_speaker"])
        existing = targets.get(target_id)
        if existing is None:
            targets[target_id] = row
            continue
        if str(existing["target_speaker"]) != target_speaker:
            raise ValueError(
                f"target {target_id} maps to multiple speakers: "
                f"{existing['target_speaker']} and {target_speaker}"
            )
    return targets


def main() -> int:
    args = parse_args()
    source_path = Path(args.source_map)
    source_rows = read_jsonl(source_path)
    if args.available_target_map:
        available_path = Path(args.available_target_map)
        available_rows = read_jsonl(available_path)
    else:
        available_path = Path(args.target_manifest)
        available_rows = normalize_target_rows(read_jsonl(available_path))

    source_ids = [str(row["source_id"]) for row in source_rows]
    if len(source_ids) != len(set(source_ids)):
        raise ValueError("source map contains duplicate source_id values")

    targets_by_id = unique_targets(available_rows)

    grouped: dict[str, list[dict]] = defaultdict(list)
    for row in targets_by_id.values():
        grouped[str(row["target_speaker"])].append(row)
    if not grouped:
        raise ValueError("available target map has no rows")

    speakers = sorted(grouped)
    for speaker in speakers:
        grouped[speaker].sort(key=lambda row: str(row["target_id"]))

    output_rows: list[dict] = []
    selected_speakers: Counter[str] = Counter()
    selected_targets: set[str] = set()
    for source in source_rows:
        source_id = str(source["source_id"])
        rng = deterministic_rng(args.seed, source_id)
        target_speaker = rng.choice(speakers)
        target = rng.choice(grouped[target_speaker])
        target_id = str(target["target_id"])
        if target_id not in targets_by_id:
            raise AssertionError("selected target is not in the available pool")
        output = dict(source)
        output.update(
            {
                "target_audio": target.get(
                    "target_audio", target.get("audio")
                ),
                "target_id": target_id,
                "target_speaker": target_speaker,
                "target_utterance_sampling": "speaker_uniform",
                "target_utterance_sampling_seed": args.seed,
            }
        )
        if output["target_audio"] is None:
            raise ValueError(f"target {target_id} has no audio path")
        output_rows.append(output)
        selected_speakers[target_speaker] += 1
        selected_targets.add(target_id)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as handle:
        for row in output_rows:
            handle.write(json.dumps(row, sort_keys=True) + "\n")

    group_sizes = sorted(len(rows) for rows in grouped.values())
    speaker_counts = list(selected_speakers.values())
    summary = {
        "seed": args.seed,
        "sampling": "uniform target speaker, then uniform available utterance",
        "source_map": str(source_path.resolve()),
        "available_target_map": str(available_path.resolve()),
        "available_target_map_role": (
            "target_map" if args.available_target_map else "raw_manifest"
        ),
        "available_rows": len(available_rows),
        "unique_available_targets": len(targets_by_id),
        "available_target_speakers": len(grouped),
        "available_group_size_min": group_sizes[0],
        "available_group_size_median": median(group_sizes),
        "available_group_size_mean": sum(group_sizes) / len(group_sizes),
        "available_group_size_max": group_sizes[-1],
        "source_rows": len(source_rows),
        "source_speakers": len(
            {str(row.get("source_speaker")) for row in source_rows}
        ),
        "selected_target_speakers": len(selected_speakers),
        "selected_unique_targets": len(selected_targets),
        "selected_speaker_count_min": min(speaker_counts),
        "selected_speaker_count_max": max(speaker_counts),
        "out": str(out_path.resolve()),
        "out_sha256": hashlib.sha256(out_path.read_bytes()).hexdigest(),
    }
    summary_path = Path(args.summary)
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
