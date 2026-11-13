"""Merge utterance embedding NPZs against one canonical manifest.

The shard extractor may intentionally carry a base partial forward, so an
individual shard NPZ can contain keys outside its own shard manifest. This
merger therefore treats the canonical LibriTTS manifest as the ID authority
and accepts overlap only when the duplicate vectors are bit-identical.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch

from n019.extract_speakers import save_npz_atomic
from n019.manifest import iter_jsonl, utterance_id, write_json, write_jsonl


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--canonical-manifest", required=True)
    parser.add_argument("--input", action="append", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--kind", choices=["nt", "ecapa"], default="nt")
    parser.add_argument("--dimension", type=int)
    parser.add_argument("--expected-rows", type=int)
    parser.add_argument("--expected-manifest-sha256")
    parser.add_argument("--norm-tolerance", type=float, default=1e-5)
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_npz_vectors(
    path: Path,
    *,
    dimension: int,
    canonical_ids: set[str],
    norm_tolerance: float,
) -> dict[str, np.ndarray]:
    values: dict[str, np.ndarray] = {}
    with np.load(path, allow_pickle=False) as archive:
        for key in archive.files:
            identifier = str(key)
            if identifier not in canonical_ids:
                raise ValueError(f"{path}: key not in canonical manifest: {identifier}")
            value = np.asarray(archive[key], dtype=np.float32)
            if value.shape != (dimension,):
                raise ValueError(
                    f"{path}:{identifier}: expected shape {(dimension,)}, "
                    f"got {value.shape}"
                )
            if not np.isfinite(value).all():
                raise ValueError(f"{path}:{identifier}: non-finite value")
            norm = float(np.linalg.norm(value))
            if abs(norm - 1.0) > norm_tolerance:
                raise ValueError(
                    f"{path}:{identifier}: expected unit norm, got {norm}"
                )
            values[identifier] = value
    if not values:
        raise ValueError(f"Embedding archive is empty: {path}")
    return values


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

    canonical_path = Path(args.canonical_manifest).resolve()
    canonical_rows = list(iter_jsonl(canonical_path))
    canonical_order = [utterance_id(row) for row in canonical_rows]
    canonical_ids = set(canonical_order)
    if len(canonical_ids) != len(canonical_rows):
        raise ValueError("Canonical manifest contains duplicate utterance IDs")
    if args.expected_rows is not None and len(canonical_rows) != args.expected_rows:
        raise ValueError(
            f"Expected {args.expected_rows} canonical rows, got {len(canonical_rows)}"
        )
    canonical_sha256 = sha256_file(canonical_path)
    if (
        args.expected_manifest_sha256
        and canonical_sha256 != args.expected_manifest_sha256
    ):
        raise ValueError(
            "Canonical manifest SHA256 mismatch: "
            f"{canonical_sha256} != {args.expected_manifest_sha256}"
        )

    merged: dict[str, np.ndarray] = {}
    input_metadata = []
    identical_overlap_keys: set[str] = set()
    for raw_path in args.input:
        path = Path(raw_path).resolve()
        current = load_npz_vectors(
            path,
            dimension=dimension,
            canonical_ids=canonical_ids,
            norm_tolerance=args.norm_tolerance,
        )
        overlap = set(merged).intersection(current)
        for identifier in overlap:
            if not np.array_equal(merged[identifier], current[identifier]):
                raise ValueError(
                    f"Conflicting duplicate embedding for {identifier}: {path}"
                )
        identical_overlap_keys.update(overlap)
        merged.update(current)
        input_metadata.append(
            {
                "path": str(path),
                "keys": len(current),
                "npz_sha256": sha256_file(path),
            }
        )

    missing = canonical_ids - set(merged)
    if missing:
        first = sorted(missing)[:10]
        raise ValueError(
            f"Missing {len(missing)} canonical embeddings; first={first}"
        )

    ordered_arrays = [merged[identifier] for identifier in canonical_order]
    all_values = np.stack(ordered_arrays)
    norms = np.linalg.norm(all_values, axis=1)
    ordered_embeddings = {
        identifier: torch.from_numpy(merged[identifier])
        for identifier in canonical_order
    }

    output_dir = Path(args.out)
    output_dir.mkdir(parents=True, exist_ok=True)
    npz_path = output_dir / f"{args.kind}_utterance_embeddings.npz"
    save_npz_atomic(npz_path, ordered_embeddings)
    output_manifest_path = output_dir / f"{args.kind}_utterance_manifest.jsonl"
    write_jsonl(output_manifest_path, canonical_rows)
    metadata = {
        "kind": args.kind,
        "level": "utterance",
        "rows": len(ordered_embeddings),
        "dimension": dimension,
        "minimum_norm": float(norms.min()),
        "maximum_norm": float(norms.max()),
        "canonical_manifest": str(canonical_path),
        "canonical_manifest_sha256": canonical_sha256,
        "embeddings_sha256": sha256_file(npz_path),
        "manifest_sha256": sha256_file(output_manifest_path),
        "identical_overlap_keys": len(identical_overlap_keys),
        "inputs": input_metadata,
    }
    write_json(output_dir / "metadata.json", metadata)
    print(json.dumps(metadata, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
