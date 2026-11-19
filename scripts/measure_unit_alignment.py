#!/usr/bin/env python3
"""Measure agreement after mapping a layer-specific code sequence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from n019.manifest import iter_jsonl, utterance_id


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference-records", required=True)
    parser.add_argument("--target-records", required=True)
    parser.add_argument("--mapping", required=True)
    parser.add_argument("--limit", type=int, default=2000)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    archive = np.load(args.mapping, allow_pickle=False)
    mapping = archive["target_to_reference"].astype(np.int64)
    archive.close()
    reference = {
        utterance_id(row): row for row in iter_jsonl(args.reference_records)
    }
    target_rows = list(iter_jsonl(args.target_records))[: args.limit]
    total = 0
    correct = 0
    boundary_total = 0
    boundary_correct = 0
    for row in target_rows:
        identifier = utterance_id(row)
        other = reference[identifier]
        reference_codes = np.load(other["codes_path"]).astype(np.int64)
        target_codes = np.load(row["codes_path"]).astype(np.int64)
        if reference_codes.shape != target_codes.shape:
            raise SystemExit(f"Frame mismatch: {identifier}")
        mapped = mapping[target_codes]
        total += int(reference_codes.size)
        correct += int((mapped == reference_codes).sum())
        if reference_codes.size > 1:
            reference_boundaries = reference_codes[1:] != reference_codes[:-1]
            target_boundaries = target_codes[1:] != target_codes[:-1]
            boundary_total += int(reference_boundaries.size)
            boundary_correct += int(
                (reference_boundaries == target_boundaries).sum()
            )
    result = {
        "records": len(target_rows),
        "frames": total,
        "token_agreement": correct / max(1, total),
        "boundary_agreement": boundary_correct / max(1, boundary_total),
    }
    Path(args.out).write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
