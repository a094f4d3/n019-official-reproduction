"""Build paired source-manifest and target-map subsets for a timing pilot."""

from __future__ import annotations

import argparse
from pathlib import Path

from n019.manifest import iter_jsonl, utterance_id, write_json, write_jsonl


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-manifest", required=True)
    parser.add_argument("--target-map", required=True)
    parser.add_argument("--rows", type=int, required=True)
    parser.add_argument("--out-source", required=True)
    parser.add_argument("--out-target-map", required=True)
    parser.add_argument("--out-meta", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.rows <= 0:
        raise ValueError("--rows must be positive")

    sources = []
    for row in iter_jsonl(args.source_manifest):
        sources.append(row)
        if len(sources) == args.rows:
            break
    if len(sources) != args.rows:
        raise ValueError(
            f"Source manifest has only {len(sources)} rows, requested {args.rows}"
        )
    source_ids = {utterance_id(row) for row in sources}
    if len(source_ids) != len(sources):
        raise ValueError("Pilot source manifest contains duplicate IDs")

    targets = [
        row for row in iter_jsonl(args.target_map)
        if row["source_id"] in source_ids
    ]
    covered = {row["source_id"] for row in targets}
    if covered != source_ids:
        missing = sorted(source_ids - covered)
        raise ValueError(
            f"Target map misses {len(missing)} pilot sources: {missing[:3]}"
        )

    write_jsonl(args.out_source, sources)
    write_jsonl(args.out_target_map, targets)
    write_json(
        args.out_meta,
        {
            "rows": len(sources),
            "target_rows": len(targets),
            "source_manifest": str(Path(args.source_manifest).resolve()),
            "target_map": str(Path(args.target_map).resolve()),
        },
    )
    print(
        f"pilot rows={len(sources)} target_rows={len(targets)} "
        f"source={args.out_source} target_map={args.out_target_map}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
