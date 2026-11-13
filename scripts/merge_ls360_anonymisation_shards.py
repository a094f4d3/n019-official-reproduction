#!/usr/bin/env python3
"""Merge independently generated LS360 shards into one VPC-ready run."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path


def read_jsonl(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(16 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-manifest", type=Path, required=True)
    parser.add_argument("--shard-root", type=Path, required=True)
    parser.add_argument("--shards", type=int, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--expected-records", type=int, default=104014)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    sources = read_jsonl(args.source_manifest)
    source_ids = {str(row["id"]) for row in sources}
    if len(source_ids) != args.expected_records:
        raise ValueError(
            f"Expected {args.expected_records} source IDs, "
            f"found {len(source_ids)}"
        )

    args.out_dir.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    elapsed_seconds = 0.0
    negative_duration_values = 0
    shard_meta = []
    duration_modes: set[str] = set()
    vocoder_types: set[str] = set()
    for index in range(args.shards):
        shard_dir = args.shard_root / f"shard_{index}"
        if (shard_dir / "anon.jsonl").is_file():
            manifest_dir = shard_dir
        elif (shard_dir / "anon" / "anon.jsonl").is_file():
            manifest_dir = shard_dir / "anon"
        else:
            raise FileNotFoundError(
                f"Missing anon.jsonl under {shard_dir} or {shard_dir / 'anon'}"
            )
        anon_path = manifest_dir / "anon.jsonl"
        meta_path = manifest_dir / "run_meta.json"
        shard_rows = read_jsonl(anon_path)
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if int(meta.get("records", -1)) != len(shard_rows):
            raise ValueError(f"Shard {index} row count does not match metadata")
        meta_args = meta.get("args", {})
        if meta_args.get("duration_mode"):
            duration_modes.add(str(meta_args["duration_mode"]))
        if meta_args.get("vocoder_type"):
            vocoder_types.add(str(meta_args["vocoder_type"]))
        elapsed_seconds += float(meta.get("elapsed_seconds", 0.0))
        negative_duration_values += int(
            meta.get("negative_duration_values", 0)
        )
        for row in shard_rows:
            source = Path(str(row["audio"]))
            if not source.is_file():
                raise FileNotFoundError(source)
            destination = args.out_dir / source.name
            if destination.exists():
                raise FileExistsError(destination)
            try:
                os.link(source, destination)
            except OSError:
                shutil.copy2(source, destination)
            new_row = dict(row)
            new_row["audio"] = str(destination.resolve())
            rows.append(new_row)
        shard_meta.append(
            {
                "index": index,
                "rows": len(shard_rows),
                "anon_jsonl_sha256": sha256_file(anon_path),
                "run_meta_sha256": sha256_file(meta_path),
            }
        )

    rows.sort(key=lambda row: str(row["id"]))
    ids = [str(row["id"]) for row in rows]
    if len(set(ids)) != len(ids) or set(ids) != source_ids:
        raise ValueError("Merged output IDs do not match the source manifest")
    wavs = sorted(args.out_dir.glob("*.wav"))
    if len(wavs) != args.expected_records:
        raise ValueError(f"Expected {args.expected_records} WAVs, found {len(wavs)}")
    if len(duration_modes) != 1:
        raise ValueError(f"Inconsistent shard duration modes: {duration_modes}")
    if len(vocoder_types) != 1:
        raise ValueError(f"Inconsistent shard vocoder types: {vocoder_types}")

    anon_path = args.out_dir / "anon.jsonl"
    with anon_path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, sort_keys=True) + "\n")
    metadata = {
        "records": len(rows),
        "elapsed_seconds": elapsed_seconds,
        "negative_duration_values": negative_duration_values,
        "args": {
            "duration_mode": duration_modes.pop(),
            "vocoder_type": vocoder_types.pop(),
        },
        "shards": shard_meta,
        "source_manifest": str(args.source_manifest.resolve()),
        "source_manifest_sha256": sha256_file(args.source_manifest),
        "anon_jsonl_sha256": sha256_file(anon_path),
    }
    meta_path = args.out_dir / "run_meta.json"
    meta_path.write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(metadata, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
