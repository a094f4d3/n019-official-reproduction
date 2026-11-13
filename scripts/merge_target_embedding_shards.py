"""Merge disjoint target-embedding shards and verify the complete ID set."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

from n019.extract_speakers import save_npz_atomic
from n019.manifest import iter_jsonl, utterance_id, write_json, write_jsonl

import torch


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--shard-dir", action="append", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--kind", choices=["nt", "ecapa"], default="nt")
    parser.add_argument("--dimension", type=int)
    parser.add_argument("--expected-rows", type=int)
    parser.add_argument("--expected-manifest-sha256")
    return parser.parse_args()


def load_manifest_rows(path: Path) -> list[dict]:
    return list(iter_jsonl(path))


def main() -> int:
    args = parse_args()
    dimension = args.dimension
    if dimension is None:
        dimension = 250 if args.kind == "nt" else 192
    expected_dimension = 250 if args.kind == "nt" else 192
    if dimension != expected_dimension:
        raise ValueError(
            f"{args.kind} embeddings must be {expected_dimension}-D, "
            f"not {dimension}-D"
        )
    manifest_path = Path(args.manifest).resolve()
    expected_rows = load_manifest_rows(manifest_path)
    expected_id_order = [utterance_id(row) for row in expected_rows]
    expected_ids = set(expected_id_order)
    if len(expected_ids) != len(expected_rows):
        raise ValueError("Expected manifest contains duplicate utterance IDs")
    manifest_sha256 = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    if args.expected_rows is not None and len(expected_rows) != args.expected_rows:
        raise ValueError(
            f"Expected {args.expected_rows} manifest rows, got {len(expected_rows)}"
        )
    if (
        args.expected_manifest_sha256
        and manifest_sha256 != args.expected_manifest_sha256
    ):
        raise ValueError(
            "Canonical source manifest SHA256 mismatch: "
            f"{manifest_sha256} != {args.expected_manifest_sha256}"
        )

    embeddings: dict[str, torch.Tensor] = {}
    input_metadata = []
    for raw_dir in args.shard_dir:
        shard_dir = Path(raw_dir)
        npz_path = shard_dir / f"{args.kind}_utterance_embeddings.npz"
        shard_manifest_path = shard_dir / f"{args.kind}_utterance_manifest.jsonl"
        archive = np.load(npz_path, allow_pickle=False)
        shard_values = {
            key: torch.from_numpy(archive[key].astype(np.float32))
            for key in archive.files
        }
        archive.close()
        rows = load_manifest_rows(shard_manifest_path)
        row_ids = {utterance_id(row) for row in rows}
        if row_ids != set(shard_values):
            raise ValueError(f"Shard IDs do not match embeddings: {shard_dir}")
        duplicates = set(embeddings).intersection(shard_values)
        if duplicates:
            raise ValueError(f"Duplicate IDs across shards: {sorted(duplicates)[:5]}")
        embeddings.update(shard_values)
        input_metadata.append(
            {
                "shard_dir": str(shard_dir.resolve()),
                "rows": len(shard_values),
                "npz_sha256": hashlib.sha256(npz_path.read_bytes()).hexdigest(),
                "manifest_sha256": hashlib.sha256(
                    shard_manifest_path.read_bytes()
                ).hexdigest(),
            }
        )

    if set(embeddings) != expected_ids:
        missing = sorted(expected_ids - set(embeddings))[:10]
        extra = sorted(set(embeddings) - expected_ids)[:10]
        raise ValueError(f"ID mismatch; missing={missing} extra={extra}")
    if any(value.numel() != dimension for value in embeddings.values()):
        raise ValueError("At least one embedding has the wrong dimension")
    # Preserve the canonical source-manifest order, not shard-manifest order.
    # d3 rewrites absolute audio paths to its own home, so those rows must not
    # become the shared output manifest.
    output_rows = expected_rows
    ordered_embeddings = {
        identifier: embeddings[identifier]
        for identifier in expected_id_order
    }
    values = torch.stack(list(ordered_embeddings.values()))
    if not bool(torch.isfinite(values).all()):
        raise ValueError("Merged embeddings contain non-finite values")
    norms = values.norm(dim=1)

    output_dir = Path(args.out)
    npz_path = output_dir / f"{args.kind}_utterance_embeddings.npz"
    save_npz_atomic(npz_path, ordered_embeddings)
    output_manifest_path = output_dir / f"{args.kind}_utterance_manifest.jsonl"
    write_jsonl(output_manifest_path, output_rows)
    write_json(
        output_dir / "metadata.json",
        {
            "kind": args.kind,
            "level": "utterance",
            "rows": len(ordered_embeddings),
            "dimension": dimension,
            "minimum_norm": float(norms.min()),
            "maximum_norm": float(norms.max()),
            "source_manifest": str(manifest_path),
            "source_manifest_sha256": manifest_sha256,
            "embeddings_sha256": hashlib.sha256(npz_path.read_bytes()).hexdigest(),
            "manifest_sha256": hashlib.sha256(
                output_manifest_path.read_bytes()
            ).hexdigest(),
            "inputs": input_metadata,
        },
    )
    print(
        json.dumps(
            {
                "rows": len(ordered_embeddings),
                "kind": args.kind,
                "dimension": dimension,
                "minimum_norm": float(norms.min()),
                "maximum_norm": float(norms.max()),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
