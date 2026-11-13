#!/usr/bin/env python3
"""Split LS360 source, unit, and target manifests for balanced inference."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def read_jsonl(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def write_jsonl(path: Path, rows: list[dict]) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, sort_keys=True) + "\n")
    return hashlib.sha256(path.read_bytes()).hexdigest()


def row_id(row: dict) -> str:
    return str(row.get("id") or row.get("source_id") or row.get("utterance_id"))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-manifest", type=Path, required=True)
    parser.add_argument("--unit-records", type=Path, required=True)
    parser.add_argument("--target-map", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--shards", type=int, required=True)
    parser.add_argument("--expected-records", type=int, default=104014)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.shards <= 0:
        raise ValueError("--shards must be positive")
    sources = read_jsonl(args.source_manifest)
    units = read_jsonl(args.unit_records)
    targets = read_jsonl(args.target_map)
    if len(sources) != args.expected_records:
        raise ValueError(
            f"Expected {args.expected_records} sources, found {len(sources)}"
        )
    if len(units) != len(sources) or len(targets) != len(sources):
        raise ValueError("Source, unit, and target row counts differ")

    unit_by_id = {row_id(row): row for row in units}
    target_by_id = {str(row["source_id"]): row for row in targets}
    source_ids = [row_id(row) for row in sources]
    if len(set(source_ids)) != len(source_ids):
        raise ValueError("Duplicate source IDs")
    if set(source_ids) != set(unit_by_id) or set(source_ids) != set(target_by_id):
        raise ValueError("Source IDs do not match unit or target manifests")

    shard_sources: list[list[dict]] = [[] for _ in range(args.shards)]
    shard_seconds = [0.0] * args.shards
    for row in sorted(sources, key=row_id):
        index = min(range(args.shards), key=lambda item: shard_seconds[item])
        shard_sources[index].append(row)
        shard_seconds[index] += float(row["seconds"])

    args.out_dir.mkdir(parents=True, exist_ok=True)
    summary = {
        "source_manifest": str(args.source_manifest.resolve()),
        "source_manifest_sha256": hashlib.sha256(
            args.source_manifest.read_bytes()
        ).hexdigest(),
        "unit_records": str(args.unit_records.resolve()),
        "unit_records_sha256": hashlib.sha256(
            args.unit_records.read_bytes()
        ).hexdigest(),
        "target_map": str(args.target_map.resolve()),
        "target_map_sha256": hashlib.sha256(
            args.target_map.read_bytes()
        ).hexdigest(),
        "rows": len(sources),
        "shards": [],
    }
    for index, rows in enumerate(shard_sources):
        ids = [row_id(row) for row in rows]
        directory = args.out_dir / f"shard_{index}"
        files = {
            "source": directory / "manifest.jsonl",
            "units": directory / "unit_records.jsonl",
            "targets": directory / "target_map.jsonl",
        }
        hashes = {
            "source": write_jsonl(files["source"], rows),
            "units": write_jsonl(
                files["units"],
                [unit_by_id[identifier] for identifier in ids],
            ),
            "targets": write_jsonl(
                files["targets"],
                [target_by_id[identifier] for identifier in ids],
            ),
        }
        summary["shards"].append(
            {
                "index": index,
                "rows": len(rows),
                "seconds": shard_seconds[index],
                "files": {key: str(path.resolve()) for key, path in files.items()},
                "sha256": hashes,
            }
        )

    summary_path = args.out_dir / "summary.json"
    summary_path.write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
