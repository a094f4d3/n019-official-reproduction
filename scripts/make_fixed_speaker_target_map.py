#!/usr/bin/env python3
"""Assign one target utterance to every source speaker for an L-only diagnostic."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-map", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--metadata", required=True)
    parser.add_argument("--source-speaker", default="source_speaker")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    rows = [
        json.loads(line)
        for line in Path(args.target_map).read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if not rows:
        raise ValueError("Target map is empty")

    candidates: dict[str, list[dict]] = {}
    for row in rows:
        source_speaker = str(row[args.source_speaker])
        candidates.setdefault(source_speaker, []).append(row)

    selected: dict[str, dict] = {}
    used_target_speakers: set[str] = set()
    for source_speaker in candidates:
        choice = next(
            (
                row
                for row in candidates[source_speaker]
                if str(row["target_speaker"]) not in used_target_speakers
            ),
            None,
        )
        if choice is None:
            choice = candidates[source_speaker][0]
        selected[source_speaker] = choice
        used_target_speakers.add(str(choice["target_speaker"]))

    output = []
    for row in rows:
        source_speaker = str(row[args.source_speaker])
        replacement = selected[source_speaker]
        fixed = dict(row)
        for key in (
            "target_speaker",
            "target_audio",
            "target_id",
        ):
            fixed[key] = replacement[key]
        fixed["target_selection"] = "fixed_per_source_speaker"
        output.append(fixed)

    source_to_target: dict[str, dict[str, str]] = {}
    for row in output:
        source_speaker = str(row[args.source_speaker])
        source_to_target[source_speaker] = {
            "target_speaker": str(row["target_speaker"]),
            "target_id": str(row["target_id"]),
        }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in output),
        encoding="utf-8",
    )
    metadata = {
        "source_map": str(Path(args.target_map).resolve()),
        "rows": len(output),
        "source_speakers": len(source_to_target),
        "target_speakers": len(
            {value["target_speaker"] for value in source_to_target.values()}
        ),
        "target_utterances": len(
            {value["target_id"] for value in source_to_target.values()}
        ),
        "unique_target_speakers": len(used_target_speakers)
        == len(source_to_target),
        "source_to_target": source_to_target,
        "out": str(out.resolve()),
        "out_sha256": hashlib.sha256(out.read_bytes()).hexdigest(),
    }
    metadata_path = Path(args.metadata)
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(metadata, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
