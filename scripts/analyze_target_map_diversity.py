#!/usr/bin/env python3
"""Report source-to-target diversity for an N019 target map."""

from __future__ import annotations

import argparse
import collections
import json
import statistics
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-map", required=True)
    parser.add_argument("--source-key", default="source_speaker")
    parser.add_argument("--target-key", default="target_speaker")
    return parser.parse_args()


def summary(values: list[float]) -> dict[str, float]:
    return {
        "min": min(values),
        "median": statistics.median(values),
        "mean": sum(values) / len(values),
        "max": max(values),
    }


def main() -> int:
    args = parse_args()
    grouped: dict[str, list[str]] = collections.defaultdict(list)
    rows = 0
    with Path(args.target_map).open(encoding="utf-8") as handle:
        for line in handle:
            if not line.strip():
                continue
            row = json.loads(line)
            grouped[str(row[args.source_key])].append(str(row[args.target_key]))
            rows += 1

    distinct = [len(set(values)) for values in grouped.values()]
    unique_ratio = [
        len(set(values)) / len(values) for values in grouped.values()
    ]
    max_share = []
    for values in grouped.values():
        counts = collections.Counter(values)
        max_share.append(max(counts.values()) / len(values))
    first_targets = collections.Counter(values[0] for values in grouped.values())
    report = {
        "target_map": str(Path(args.target_map).resolve()),
        "rows": rows,
        "source_speakers": len(grouped),
        "target_speakers": len(
            {value for values in grouped.values() for value in values}
        ),
        "source_rows": summary([len(values) for values in grouped.values()]),
        "distinct_targets_per_source": summary(distinct),
        "unique_target_ratio_per_source": summary(unique_ratio),
        "max_target_share_per_source": summary(max_share),
        "same_first_target_across_sources": {
            "unique_first_targets": len(first_targets),
            "most_common": first_targets.most_common(10),
        },
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
