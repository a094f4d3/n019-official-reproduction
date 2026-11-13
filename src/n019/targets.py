"""Create deterministic utterance-to-target mappings for anonymisation."""

from __future__ import annotations

import argparse
import random
from collections import defaultdict

from n019.manifest import (
    iter_jsonl,
    sha256_file,
    speaker_id,
    utterance_id,
    write_json,
    write_jsonl,
)


def build_target_map(
    source_rows: list[dict],
    target_rows: list[dict],
    *,
    seed: int,
    mode: str = "speaker",
) -> list[dict]:
    if not source_rows or not target_rows:
        raise ValueError("Source and target manifests must both be non-empty")
    source_ids = [utterance_id(row) for row in source_rows]
    target_ids = [utterance_id(row) for row in target_rows]
    if len(source_ids) != len(set(source_ids)):
        raise ValueError("Source manifest contains duplicate utterance IDs")
    if len(target_ids) != len(set(target_ids)):
        raise ValueError("Target manifest contains duplicate utterance IDs")
    rng = random.Random(seed)
    by_speaker: dict[str, list[dict]] = defaultdict(list)
    for row in target_rows:
        by_speaker[speaker_id(row)].append(row)
    target_speakers = sorted(by_speaker)
    mappings = []
    for source in source_rows:
        if mode == "speaker":
            target_speaker = target_speakers[rng.randrange(len(target_speakers))]
            options = by_speaker[target_speaker]
            target = options[rng.randrange(len(options))]
        elif mode == "utterance":
            target = target_rows[rng.randrange(len(target_rows))]
        else:
            raise ValueError(f"Unsupported target mapping mode: {mode}")
        mappings.append(
            {
                "source_id": utterance_id(source),
                "source_speaker": speaker_id(source),
                "source_audio": source["audio"],
                "target_id": utterance_id(target),
                "target_speaker": speaker_id(target),
                "target_audio": target["audio"],
            }
        )
    return mappings


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a reproducible target-speaker mapping."
    )
    parser.add_argument("--source-manifest", required=True)
    parser.add_argument("--target-manifest", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--seed", type=int, default=20261102)
    parser.add_argument(
        "--mode",
        choices=["speaker", "utterance"],
        default="speaker",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    sources = list(iter_jsonl(args.source_manifest))
    targets_manifest = list(iter_jsonl(args.target_manifest))
    mappings = build_target_map(
        sources,
        targets_manifest,
        seed=args.seed,
        mode=args.mode,
    )
    write_jsonl(args.out, mappings)
    write_json(
        f"{args.out}.meta.json",
        {
            "source_manifest": args.source_manifest,
            "target_manifest": args.target_manifest,
            "source_manifest_sha256": sha256_file(args.source_manifest),
            "target_manifest_sha256": sha256_file(args.target_manifest),
            "rows": len(mappings),
            "seed": args.seed,
            "mode": args.mode,
        },
    )
    print(f"wrote {len(mappings)} mappings to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
