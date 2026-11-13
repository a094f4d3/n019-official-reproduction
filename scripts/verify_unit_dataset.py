#!/usr/bin/env python3
"""Verify one manifest/unit-record pair against fixed expectations."""

from __future__ import annotations

import argparse
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np


def read_jsonl(path: Path) -> list[dict]:
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def inspect_record(row: dict) -> tuple[str | None, str | None]:
    path = Path(row["codes_path"])
    if not path.is_file():
        return str(path), None
    codes = np.load(path, mmap_mode="r")
    if codes.ndim != 1 or codes.shape[0] != int(row["num_frames"]):
        return None, row["id"]
    if codes.size and (int(codes.min()) < 0 or int(codes.max()) >= 200):
        return None, row["id"]
    return None, None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--unit-records", required=True)
    parser.add_argument("--codebook", required=True)
    parser.add_argument("--expected-records", type=int, required=True)
    parser.add_argument("--expected-speakers", type=int, required=True)
    parser.add_argument("--workers", type=int, default=16)
    parser.add_argument("--out", default=None)
    args = parser.parse_args()

    manifest = read_jsonl(Path(args.manifest).resolve())
    records = read_jsonl(Path(args.unit_records).resolve())
    manifest_ids = {str(row["id"]) for row in manifest}
    record_ids = [str(row["id"]) for row in records]
    speaker_ids = {str(row["speaker"]) for row in records}
    if args.workers <= 0:
        raise ValueError("--workers must be positive")
    missing_files = []
    shape_mismatches = []
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        for missing, mismatch in executor.map(inspect_record, records):
            if missing is not None:
                missing_files.append(missing)
            if mismatch is not None:
                shape_mismatches.append(mismatch)

    report = {
        "manifest": str(Path(args.manifest).resolve()),
        "unit_records": str(Path(args.unit_records).resolve()),
        "records": len(records),
        "unique_record_ids": len(set(record_ids)),
        "manifest_ids": len(manifest_ids),
        "speakers": len(speaker_ids),
        "missing_manifest_ids": len(manifest_ids - set(record_ids)),
        "extra_record_ids": len(set(record_ids) - manifest_ids),
        "missing_code_files": len(missing_files),
        "shape_or_value_mismatches": len(shape_mismatches),
        "verification_workers": args.workers,
    }
    if len(records) != args.expected_records:
        raise ValueError(
            f"Expected {args.expected_records} records, got {len(records)}"
        )
    if len(set(record_ids)) != len(records):
        raise ValueError("Unit records contain duplicate IDs")
    if set(record_ids) != manifest_ids:
        raise ValueError("Unit record IDs do not exactly match the manifest")
    if len(speaker_ids) != args.expected_speakers:
        raise ValueError(
            f"Expected {args.expected_speakers} speakers, "
            f"got {len(speaker_ids)}"
        )
    if missing_files or shape_mismatches:
        raise ValueError("Missing code files or invalid code arrays")
    if not Path(args.codebook).is_file():
        raise FileNotFoundError(args.codebook)
    encoded = json.dumps(report, indent=2, sort_keys=True)
    if args.out:
        Path(args.out).write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
