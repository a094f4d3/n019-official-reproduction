"""Select the unique target utterances referenced by a target map."""

from __future__ import annotations

import argparse

from n019.manifest import iter_jsonl, utterance_id, write_json, write_jsonl


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-map", required=True)
    parser.add_argument("--target-manifest", required=True)
    parser.add_argument("--out", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    target_ids = {
        str(row["target_id"])
        for row in iter_jsonl(args.target_map)
    }
    if not target_ids:
        raise ValueError("Target map is empty")
    selected = [
        row
        for row in iter_jsonl(args.target_manifest)
        if utterance_id(row) in target_ids
    ]
    found = {utterance_id(row) for row in selected}
    missing = sorted(target_ids - found)
    if missing:
        raise KeyError(f"Missing target manifest IDs: {missing[:10]}")
    write_jsonl(args.out, selected)
    write_json(
        f"{args.out}.meta.json",
        {
            "target_map": args.target_map,
            "target_manifest": args.target_manifest,
            "target_ids": len(target_ids),
            "selected_rows": len(selected),
        },
    )
    print(f"selected {len(selected)} target utterances")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
