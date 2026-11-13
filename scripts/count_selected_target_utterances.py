#!/usr/bin/env python3
"""Count available other-500 utterances for target speakers used by a map."""

from __future__ import annotations

import argparse
import json
import statistics
from collections import Counter
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-map", required=True)
    parser.add_argument("--target-manifest", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    target_map = Path(args.target_map)
    target_manifest = Path(args.target_manifest)

    selected = {
        str(row["target_speaker"])
        for row in map(json.loads, target_map.open(encoding="utf-8"))
    }
    counts: Counter[str] = Counter()
    rows = 0
    with target_manifest.open(encoding="utf-8") as handle:
        for line in handle:
            if not line.strip():
                continue
            row = json.loads(line)
            rows += 1
            speaker = row.get("speaker", row.get("speaker_id"))
            if speaker is None:
                raise KeyError("Target manifest row has no speaker identifier")
            speaker = str(speaker)
            if speaker in selected:
                counts[speaker] += 1

    values = sorted(counts.values())
    result = {
        "manifest_rows": rows,
        "selected_speakers": len(selected),
        "covered_speakers": len(counts),
        "selected_utterances": sum(values),
        "min": min(values),
        "max": max(values),
        "mean": statistics.fmean(values),
        "median": statistics.median(values),
        "speakers_with_at_least": {
            str(threshold): sum(value >= threshold for value in values)
            for threshold in (8, 16, 32, 64, 128)
        },
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
