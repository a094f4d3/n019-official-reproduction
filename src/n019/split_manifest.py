"""Deterministic speaker-disjoint manifest split."""

from __future__ import annotations

import argparse
import random

from n019.manifest import iter_jsonl, speaker_id, write_json, write_jsonl


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--train-out", required=True)
    parser.add_argument("--dev-out", required=True)
    parser.add_argument("--dev-fraction", type=float, default=0.05)
    parser.add_argument("--seed", type=int, default=20261102)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not 0.0 < args.dev_fraction < 1.0:
        raise ValueError("--dev-fraction must be in (0, 1)")
    rows = list(iter_jsonl(args.input))
    speakers = sorted({speaker_id(row) for row in rows})
    if len(speakers) < 2:
        raise ValueError("Need at least two speakers")
    rng = random.Random(args.seed)
    rng.shuffle(speakers)
    dev_count = max(1, round(len(speakers) * args.dev_fraction))
    dev_count = min(dev_count, len(speakers) - 1)
    dev_speakers = set(speakers[:dev_count])
    train_rows = [row for row in rows if speaker_id(row) not in dev_speakers]
    dev_rows = [row for row in rows if speaker_id(row) in dev_speakers]
    if not train_rows or not dev_rows:
        raise RuntimeError("Speaker split produced an empty side")
    write_jsonl(args.train_out, train_rows)
    write_jsonl(args.dev_out, dev_rows)
    write_json(
        f"{args.train_out}.split.json",
        {
            "seed": args.seed,
            "dev_fraction": args.dev_fraction,
            "dev_speakers": sorted(dev_speakers),
            "train_utterances": len(train_rows),
            "dev_utterances": len(dev_rows),
        },
    )
    print(f"train={len(train_rows)} dev={len(dev_rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
