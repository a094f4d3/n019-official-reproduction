"""Split an embedding manifest into deterministic, disjoint JSONL shards."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from n019.manifest import iter_jsonl, utterance_id, write_json, write_jsonl


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--shards", type=int, required=True)
    parser.add_argument("--audio-prefix-from")
    parser.add_argument("--audio-prefix-to")
    return parser.parse_args()


def rewrite_audio(row: dict, source: str, destination: str) -> dict:
    row = dict(row)
    audio = str(row["audio"])
    if not audio.startswith(source):
        raise ValueError(f"Audio path is outside expected prefix: {audio}")
    row["audio"] = destination + audio[len(source) :]
    return row


def main() -> int:
    args = parse_args()
    if args.shards < 1:
        raise ValueError("--shards must be positive")
    if bool(args.audio_prefix_from) != bool(args.audio_prefix_to):
        raise ValueError("Both audio-prefix arguments must be provided together")

    source = Path(args.manifest)
    rows = list(iter_jsonl(source))
    if not rows:
        raise ValueError("Manifest is empty")
    identifiers = [utterance_id(row) for row in rows]
    if len(set(identifiers)) != len(identifiers):
        raise ValueError("Manifest contains duplicate utterance IDs")

    output_dir = Path(args.out_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    shard_rows = [[] for _ in range(args.shards)]
    for index, row in enumerate(rows):
        if args.audio_prefix_from:
            row = rewrite_audio(
                row,
                args.audio_prefix_from,
                args.audio_prefix_to,
            )
        shard_rows[index % args.shards].append(row)

    shard_files = []
    for index, values in enumerate(shard_rows):
        path = output_dir / f"shard_{index:03d}.jsonl"
        write_jsonl(path, values)
        shard_files.append(
            {
                "index": index,
                "path": str(path.resolve()),
                "rows": len(values),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            }
        )

    all_shard_ids = {
        utterance_id(row) for values in shard_rows for row in values
    }
    if all_shard_ids != set(identifiers):
        raise RuntimeError("Shard union does not match the input manifest")

    write_json(
        output_dir / "shards.json",
        {
            "source_manifest": str(source.resolve()),
            "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "source_rows": len(rows),
            "shards": shard_files,
            "audio_prefix_from": args.audio_prefix_from,
            "audio_prefix_to": args.audio_prefix_to,
        },
    )
    print(json.dumps({"rows": len(rows), "shards": shard_files}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
