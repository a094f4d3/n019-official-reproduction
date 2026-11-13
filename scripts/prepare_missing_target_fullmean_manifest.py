#!/usr/bin/env python3
"""Build an utterance manifest for target speakers missing a full-mean embedding.

The N019 paper specifies a target speaker embedding sampled from the original
LibriTTS train-other-500 pool.  Existing mean32 development artifacts are only
an approximation.  This audit identifies which speakers are absent from the
full-utterance speaker-mean archive and writes their complete utterance rows
for one exact extraction pass.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

import numpy as np


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def iter_jsonl(path: Path):
    with path.open(encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            row = json.loads(line)
            if not isinstance(row, dict):
                raise ValueError(f"{path}:{line_number}: expected an object")
            yield row


def normalize_speaker(value: object) -> str:
    text = str(value).strip()
    if not text:
        raise ValueError("Empty speaker ID")
    # LibriTTS speaker IDs are numeric.  Keep any future non-numeric IDs
    # verbatim rather than silently coercing them to a different namespace.
    return text


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all-utterances", required=True)
    parser.add_argument(
        "--existing-fullmean-embeddings",
        required=True,
        help="NPZ containing keys for speakers that already have a full mean",
    )
    parser.add_argument(
        "--target-map",
        action="append",
        default=[],
        help="Speaker-sampled target map; repeat for test and LS360",
    )
    parser.add_argument(
        "--include-all-pool-speakers",
        action="store_true",
        help="Treat every speaker in the LibriTTS pool as a target, including "
        "speakers not yet referenced by an existing target map",
    )
    parser.add_argument(
        "--speaker-id",
        action="append",
        default=[],
        help="Explicit target speaker ID; repeat as needed",
    )
    parser.add_argument("--out", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--expected-existing-speakers", type=int)
    parser.add_argument("--expected-target-speakers", type=int)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    all_utterances_path = Path(args.all_utterances)
    existing_path = Path(args.existing_fullmean_embeddings)

    archive = np.load(existing_path, allow_pickle=False)
    try:
        existing = {normalize_speaker(key) for key in archive.files}
        for key in archive.files:
            value = archive[key]
            if value.shape != (250,):
                raise ValueError(f"{existing_path}: {key} has shape {value.shape}")
            if not np.isfinite(value).all():
                raise ValueError(f"{existing_path}: {key} is non-finite")
    finally:
        archive.close()

    target_speakers: set[str] = set()
    target_map_audit = []
    for raw_path in args.target_map:
        path = Path(raw_path)
        speakers = {
            normalize_speaker(row["target_speaker"])
            for row in iter_jsonl(path)
        }
        target_speakers.update(speakers)
        target_map_audit.append(
            {
                "path": str(path.resolve()),
                "sha256": sha256_file(path),
                "speakers": len(speakers),
            }
        )
    target_speakers.update(normalize_speaker(value) for value in args.speaker_id)
    if not target_speakers and not args.include_all_pool_speakers:
        raise ValueError(
            "Provide --target-map, --include-all-pool-speakers, or --speaker-id"
        )

    all_speakers = {
        normalize_speaker(row["speaker"])
        for row in iter_jsonl(all_utterances_path)
    }
    if args.include_all_pool_speakers:
        target_speakers = set(all_speakers)

    missing = target_speakers - existing
    if args.expected_existing_speakers is not None:
        if len(existing) != args.expected_existing_speakers:
            raise ValueError(
                f"Expected {args.expected_existing_speakers} existing speakers, "
                f"found {len(existing)}"
            )
    if args.expected_target_speakers is not None:
        if len(target_speakers) != args.expected_target_speakers:
            raise ValueError(
                f"Expected {args.expected_target_speakers} target speakers, "
                f"found {len(target_speakers)}"
            )

    rows = []
    counts: Counter[str] = Counter()
    seen_ids: set[str] = set()
    for row in iter_jsonl(all_utterances_path):
        speaker = normalize_speaker(row["speaker"])
        all_speakers.add(speaker)
        if speaker not in missing:
            continue
        utterance_id = str(row.get("id") or row.get("utterance_id") or "")
        if not utterance_id:
            raise ValueError("Missing utterance id in all-utterances manifest")
        if utterance_id in seen_ids:
            raise ValueError(f"Duplicate utterance ID: {utterance_id}")
        seen_ids.add(utterance_id)
        rows.append(row)
        counts[speaker] += 1

    absent_from_pool = missing - all_speakers
    empty_missing = {speaker for speaker in missing if counts[speaker] == 0}
    if absent_from_pool or empty_missing:
        raise ValueError(
            "Missing target speakers are absent from the LibriTTS pool: "
            f"absent={sorted(absent_from_pool)} no_rows={sorted(empty_missing)}"
        )

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, sort_keys=True) + "\n")

    report = {
        "all_utterances": {
            "path": str(all_utterances_path.resolve()),
            "sha256": sha256_file(all_utterances_path),
            "speakers": len(all_speakers),
            "rows_in_source": sum(1 for _ in iter_jsonl(all_utterances_path)),
        },
        "existing_fullmean": {
            "path": str(existing_path.resolve()),
            "sha256": sha256_file(existing_path),
            "speakers": len(existing),
        },
        "target_maps": target_map_audit,
        "target_speakers": len(target_speakers),
        "target_speakers_absent_from_pool": sorted(
            target_speakers - all_speakers
        ),
        "pool_speakers_not_referenced_by_target_maps": sorted(
            all_speakers - target_speakers
        ),
        "missing_speakers": len(missing),
        "missing_speaker_ids": sorted(missing),
        "missing_rows": len(rows),
        "missing_group_min": min(counts.values()) if counts else 0,
        "missing_group_median": (
            float(np.median(list(counts.values()))) if counts else 0
        ),
        "missing_group_mean": (
            float(np.mean(list(counts.values()))) if counts else 0
        ),
        "missing_group_max": max(counts.values()) if counts else 0,
        "out": str(out.resolve()),
        "out_sha256": sha256_file(out),
    }
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
