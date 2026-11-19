#!/usr/bin/env python3
"""Combine the self-contained test records with layer-9 unit code paths."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-records", required=True)
    parser.add_argument("--layer9-records", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--summary", required=True)
    return parser.parse_args()


def read_jsonl(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    args = parse_args()
    source_path = Path(args.source_records)
    layer9_path = Path(args.layer9_records)
    source_rows = read_jsonl(source_path)
    layer9_rows = read_jsonl(layer9_path)
    source_by_id = {str(row["id"]): row for row in source_rows}
    layer9_by_id = {str(row["id"]): row for row in layer9_rows}
    if len(source_by_id) != 1934 or set(source_by_id) != set(layer9_by_id):
        raise SystemExit(
            "Source and layer-9 records must contain the same 1,934 unique IDs"
        )

    output_rows = []
    for identifier in sorted(source_by_id):
        source = dict(source_by_id[identifier])
        layer9 = layer9_by_id[identifier]
        codes_path = Path(str(layer9["codes_path"]))
        if not codes_path.is_file():
            raise FileNotFoundError(codes_path)
        source["codes_path"] = str(codes_path)
        source["hubert_layer"] = 9
        source["kmeans_k"] = int(layer9["kmeans_k"])
        source["kmeans_codebook"] = str(layer9["kmeans_codebook"])
        source["num_frames"] = int(layer9["num_frames"])
        source["num_frames_collapsed"] = int(layer9["num_frames_collapsed"])
        output_rows.append(source)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as handle:
        for row in output_rows:
            handle.write(json.dumps(row, sort_keys=True) + "\n")

    summary = {
        "source_records": str(source_path.resolve()),
        "source_records_sha256": sha256(source_path),
        "layer9_records": str(layer9_path.resolve()),
        "layer9_records_sha256": sha256(layer9_path),
        "records": len(output_rows),
        "out": str(out_path.resolve()),
        "out_sha256": sha256(out_path),
    }
    summary_path = Path(args.summary)
    summary_path.write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
