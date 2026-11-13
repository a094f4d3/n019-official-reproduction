"""Summarise a JSONL audio manifest without loading audio files."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from n019.manifest import iter_jsonl


def summarize_manifest(rows: list[dict]) -> dict:
    if not rows:
        raise ValueError("Manifest is empty")
    seconds = [float(row["seconds"]) for row in rows]
    speakers = {str(row["speaker"]) for row in rows}
    return {
        "rows": len(rows),
        "speakers": len(speakers),
        "seconds": sum(seconds),
        "hours": sum(seconds) / 3600.0,
        "mean_seconds": sum(seconds) / len(seconds),
        "min_seconds": min(seconds),
        "max_seconds": max(seconds),
        "sample_rates": sorted({int(row["sample_rate"]) for row in rows}),
        "channels": sorted({int(row["channels"]) for row in rows}),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Summarise an audio manifest.")
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--out", default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = summarize_manifest(list(iter_jsonl(args.manifest)))
    encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.out:
        path = Path(args.out)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
