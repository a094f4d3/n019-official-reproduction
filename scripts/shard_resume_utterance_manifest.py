#!/usr/bin/env python3
"""Split unprocessed utterance rows into speaker-disjoint resume shards."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

import numpy as np


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--records", required=True)
    parser.add_argument("--partial-npz", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--shards", type=int, default=3)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.shards < 1:
        raise ValueError("--shards must be positive")

    with np.load(args.partial_npz, allow_pickle=False) as archive:
        completed = set(archive.files)

    grouped: dict[str, list[dict]] = defaultdict(list)
    total = 0
    with Path(args.records).open(encoding="utf-8") as handle:
        for line in handle:
            row = json.loads(line)
            total += 1
            if str(row["id"]) not in completed:
                grouped[str(row["speaker"])].append(row)

    remaining = sum(len(rows) for rows in grouped.values())
    if total - len(completed) != remaining:
        raise RuntimeError(
            "partial keys do not match records: "
            f"records={total} completed={len(completed)} remaining={remaining}"
        )

    shard_rows: list[list[dict]] = [[] for _ in range(args.shards)]
    shard_counts = [0] * args.shards
    assignments = []
    for speaker, rows in sorted(
        grouped.items(),
        key=lambda item: (-len(item[1]), int(item[0])),
    ):
        index = min(range(args.shards), key=lambda value: (shard_counts[value], value))
        shard_rows[index].extend(rows)
        shard_counts[index] += len(rows)
        assignments.append(
            {
                "speaker": speaker,
                "rows": len(rows),
                "shard": index,
            }
        )

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    shard_paths = []
    for index, rows in enumerate(shard_rows):
        path = out_dir / f"shard_{index}.jsonl"
        with path.open("w", encoding="utf-8") as handle:
            for row in rows:
                handle.write(json.dumps(row, ensure_ascii=False) + "\n")
        shard_paths.append({"path": str(path), "rows": len(rows)})

    summary = {
        "records": total,
        "completed": len(completed),
        "remaining": remaining,
        "shards": shard_paths,
        "assignments": assignments,
    }
    (out_dir / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({**summary, "assignments": len(assignments)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
