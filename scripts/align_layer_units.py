#!/usr/bin/env python3
"""Align a layer-specific unit vocabulary to the layer-6 token order.

K-means cluster labels are arbitrary. Reordering a layer-9 codebook to the
layer-6 labels by maximum frame co-occurrence preserves the same tokens while
making pretrained layer-6 conditioning reusable for a controlled screen.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from scipy.optimize import linear_sum_assignment

from n019.manifest import (
    iter_jsonl,
    safe_filename,
    sha256_file,
    utterance_id,
    write_json,
    write_jsonl,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference-records", required=True)
    parser.add_argument("--target-records", required=True)
    parser.add_argument("--reference-codebook", required=True)
    parser.add_argument("--target-codebook", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--k", type=int, default=200)
    return parser.parse_args()


def load_centroids(path: Path) -> np.ndarray:
    archive = np.load(path, allow_pickle=False)
    centroids = archive["centroids"].astype(np.float32)
    archive.close()
    if centroids.ndim != 2:
        raise ValueError(f"Invalid centroid shape: {centroids.shape}")
    if not np.isfinite(centroids).all():
        raise ValueError("Codebook contains non-finite centroids")
    return centroids


def load_codes(path: str, k: int) -> np.ndarray:
    codes = np.load(path).astype(np.int64, copy=False)
    if codes.ndim != 1 or codes.size == 0:
        raise ValueError(f"Invalid code sequence: {path}")
    if int(codes.min()) < 0 or int(codes.max()) >= k:
        raise ValueError(f"Code outside [0, {k}): {path}")
    return codes


def cooccurrence_mapping(
    reference_rows: list[dict],
    target_rows: list[dict],
    *,
    k: int,
) -> tuple[np.ndarray, np.ndarray]:
    if len(reference_rows) != len(target_rows):
        raise ValueError("Reference and target row counts differ")
    counts = np.zeros((k, k), dtype=np.int64)
    for index, (reference, target) in enumerate(
        zip(reference_rows, target_rows, strict=True),
        1,
    ):
        if utterance_id(reference) != utterance_id(target):
            raise ValueError(
                f"Row-order mismatch at {index}: "
                f"{utterance_id(reference)} != {utterance_id(target)}"
            )
        reference_codes = load_codes(reference["codes_path"], k)
        target_codes = load_codes(target["codes_path"], k)
        if reference_codes.shape != target_codes.shape:
            raise ValueError(
                f"Frame mismatch for {utterance_id(reference)}: "
                f"{reference_codes.shape} != {target_codes.shape}"
            )
        np.add.at(counts, (reference_codes, target_codes), 1)
        if index % 2000 == 0 or index == len(reference_rows):
            print(f"aligned_frames={index}/{len(reference_rows)}", flush=True)
    reference_ids, target_ids = linear_sum_assignment(-counts)
    if len(reference_ids) != k or len(set(target_ids.tolist())) != k:
        raise RuntimeError("Hungarian assignment did not produce a bijection")
    return reference_ids.astype(np.int64), target_ids.astype(np.int64)


def main() -> int:
    args = parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    reference_rows = list(iter_jsonl(args.reference_records))
    target_rows = list(iter_jsonl(args.target_records))
    reference_ids, target_ids = cooccurrence_mapping(
        reference_rows,
        target_rows,
        k=args.k,
    )
    mapping = np.full(args.k, -1, dtype=np.int16)
    mapping[target_ids] = reference_ids.astype(np.int16)
    if bool((mapping < 0).any()):
        raise RuntimeError("Incomplete target-to-reference mapping")

    reference_centroids = load_centroids(Path(args.reference_codebook))
    target_centroids = load_centroids(Path(args.target_codebook))
    if reference_centroids.shape != (args.k, target_centroids.shape[1]):
        raise ValueError("Reference codebook shape is incompatible")
    if target_centroids.shape[0] != args.k:
        raise ValueError("Target codebook shape is incompatible")
    aligned_centroids = np.empty_like(target_centroids)
    aligned_centroids[reference_ids] = target_centroids[target_ids]

    aligned_codebook = out / "kmeans_aligned_to_layer6.npz"
    np.savez_compressed(
        aligned_codebook,
        centroids=aligned_centroids,
        metadata_json=np.array(
            json.dumps(
                {
                    "k": args.k,
                    "source_target_codebook": str(
                        Path(args.target_codebook).resolve()
                    ),
                    "reference_codebook": str(
                        Path(args.reference_codebook).resolve()
                    ),
                    "alignment": "Hungarian maximum frame co-occurrence",
                }
            )
        ),
    )

    codes_dir = out / "codes"
    codes_dir.mkdir(parents=True, exist_ok=True)
    output_rows = []
    for target in target_rows:
        identifier = utterance_id(target)
        codes = load_codes(target["codes_path"], args.k)
        aligned = mapping[codes]
        destination = codes_dir / safe_filename(identifier, ".npy")
        temporary = destination.with_suffix(destination.suffix + ".tmp")
        with temporary.open("wb") as handle:
            np.save(handle, aligned.astype(np.int16))
        temporary.replace(destination)
        row = dict(target)
        row["original_codes_path"] = target["codes_path"]
        row["original_kmeans_codebook"] = target.get("kmeans_codebook")
        row["codes_path"] = str(destination)
        row["kmeans_codebook"] = str(aligned_codebook)
        row["layer_alignment"] = "layer9_to_layer6_hungarian_v1"
        output_rows.append(row)

    records = out / "unit_records.jsonl"
    write_jsonl(records, output_rows)
    np.savez_compressed(
        out / "alignment.npz",
        target_to_reference=mapping,
        reference_ids=reference_ids,
        target_ids=target_ids,
    )
    write_json(
        out / "alignment.json",
        {
            "k": args.k,
            "records": len(output_rows),
            "reference_records": len(reference_rows),
            "target_records": len(target_rows),
            "reference_codebook": str(Path(args.reference_codebook).resolve()),
            "target_codebook": str(Path(args.target_codebook).resolve()),
            "aligned_codebook": str(aligned_codebook.resolve()),
            "aligned_codebook_sha256": sha256_file(aligned_codebook),
            "records_sha256": sha256_file(records),
            "mapping": {
                str(int(target)): int(reference)
                for target, reference in zip(target_ids, reference_ids)
            },
        },
    )
    print(f"OUT={out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
