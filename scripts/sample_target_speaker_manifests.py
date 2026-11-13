#!/usr/bin/env python3
"""Build deterministic target-speaker embedding manifests for sharded extraction."""

from __future__ import annotations

import argparse
import hashlib
import json
import random
from collections import defaultdict
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-map", action="append", required=True)
    parser.add_argument("--target-manifest", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--samples-per-speaker", type=int, default=32)
    parser.add_argument("--seed", type=int, default=20261102)
    parser.add_argument("--shard-index", type=int, default=0)
    parser.add_argument("--shard-count", type=int, default=1)
    return parser.parse_args()


def row_id(row: dict) -> str:
    return str(row.get("id") or row.get("utterance_id") or Path(row["audio"]).stem)


def row_speaker(row: dict) -> str:
    value = row.get("speaker", row.get("speaker_id"))
    if value is None:
        raise KeyError("Target manifest row has no speaker identifier")
    return str(value)


def main() -> int:
    args = parse_args()
    if args.samples_per_speaker <= 0:
        raise ValueError("--samples-per-speaker must be positive")
    if args.shard_count <= 0 or not 0 <= args.shard_index < args.shard_count:
        raise ValueError("invalid shard index/count")

    selected: set[str] = set()
    for raw_path in args.target_map:
        with Path(raw_path).open(encoding="utf-8") as handle:
            for line in handle:
                if line.strip():
                    selected.add(str(json.loads(line)["target_speaker"]))

    grouped: dict[str, list[dict]] = defaultdict(list)
    with Path(args.target_manifest).open(encoding="utf-8") as handle:
        for line in handle:
            if not line.strip():
                continue
            row = json.loads(line)
            speaker = row_speaker(row)
            if speaker in selected:
                grouped[speaker].append(row)

    missing = sorted(selected - set(grouped))
    if missing:
        raise RuntimeError(f"selected speakers missing from manifest: {missing[:5]}")

    shard_speakers = sorted(grouped)[args.shard_index :: args.shard_count]
    rows: list[dict] = []
    group_sizes: dict[str, int] = {}
    for speaker in shard_speakers:
        options = sorted(grouped[speaker], key=row_id)
        seed_material = f"{args.seed}:{speaker}".encode("utf-8")
        seed = int.from_bytes(hashlib.sha256(seed_material).digest()[:8], "big")
        rng = random.Random(seed)
        take = min(args.samples_per_speaker, len(options))
        chosen = rng.sample(options, take)
        chosen.sort(key=row_id)
        rows.extend(chosen)
        group_sizes[speaker] = take

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, sort_keys=True) + "\n")

    summary = {
        "seed": args.seed,
        "samples_per_speaker": args.samples_per_speaker,
        "shard_index": args.shard_index,
        "shard_count": args.shard_count,
        "selected_speakers_total": len(selected),
        "shard_speakers": len(shard_speakers),
        "rows": len(rows),
        "group_size_min": min(group_sizes.values()),
        "group_size_max": max(group_sizes.values()),
        "group_size_mean": sum(group_sizes.values()) / len(group_sizes),
        "target_maps": [str(Path(path).resolve()) for path in args.target_map],
        "target_manifest": str(Path(args.target_manifest).resolve()),
        "out": str(out.resolve()),
        "out_sha256": hashlib.sha256(out.read_bytes()).hexdigest(),
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
