#!/usr/bin/env python3
"""Check that every manifest record has a matching NPZ embedding key."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from n019.manifest import speaker_id, utterance_id


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--records", required=True)
    parser.add_argument("--embeddings", required=True)
    parser.add_argument(
        "--level",
        choices=["speaker", "utterance"],
        required=True,
    )
    parser.add_argument(
        "--key-field",
        default=None,
        help="Use this JSON field verbatim instead of speaker/utterance IDs.",
    )
    parser.add_argument("--out", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.key_field:
        key_fn = lambda row: str(row[args.key_field])
    else:
        key_fn = speaker_id if args.level == "speaker" else utterance_id
    record_keys: list[str] = []
    with open(args.records, encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                record_keys.append(key_fn(json.loads(line)))

    archive = np.load(args.embeddings)
    try:
        embedding_keys = set(archive.files)
        missing = sorted(set(record_keys) - embedding_keys)
        dimensions = sorted(
            {int(archive[key].size) for key in archive.files}
        )
    finally:
        archive.close()

    result = {
        "records": len(record_keys),
        "unique_records": len(set(record_keys)),
        "embedding_keys": len(embedding_keys),
        "missing": len(missing),
        "missing_examples": missing[:20],
        "dimensions": dimensions,
        "embedding_key_examples": sorted(embedding_keys)[:10],
        "level": args.level,
        "key_field": args.key_field,
        "records_path": str(Path(args.records).resolve()),
        "embeddings_path": str(Path(args.embeddings).resolve()),
    }
    output = Path(args.out)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if not missing else 1


if __name__ == "__main__":
    raise SystemExit(main())
