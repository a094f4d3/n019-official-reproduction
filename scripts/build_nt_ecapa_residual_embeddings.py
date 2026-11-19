"""Inject ECAPA timbral residuals into NT speaker embeddings.

A ridge map is fitted on paired clean-100 source speakers. For each target,
the ECAPA-predicted NT component is projected away from the observed NT
embedding and the orthogonal residual is added at several strengths.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np


def l2_normalize(matrix: np.ndarray) -> np.ndarray:
    norms = np.linalg.norm(matrix, axis=1, keepdims=True)
    if not np.isfinite(norms).all() or (norms <= 1e-12).any():
        raise ValueError("Cannot normalize zero or non-finite vectors")
    return matrix / norms


def load_archive(path: str | Path) -> dict[str, np.ndarray]:
    archive = np.load(path, allow_pickle=False)
    values = {
        key: archive[key].astype(np.float64)
        for key in archive.files
    }
    archive.close()
    if not values:
        raise ValueError(f"Empty embedding archive: {path}")
    dims = {int(value.size) for value in values.values()}
    if len(dims) != 1:
        raise ValueError(f"Mixed embedding dimensions in {path}: {dims}")
    return values


def fit_ridge(
    features: np.ndarray,
    targets: np.ndarray,
    *,
    weight: float,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, float]:
    if features.shape[0] != targets.shape[0]:
        raise ValueError("Paired arrays have different row counts")
    if weight <= 0.0:
        raise ValueError("Ridge weight must be positive")
    feature_mean = features.mean(axis=0)
    target_mean = targets.mean(axis=0)
    centered_features = features - feature_mean
    centered_targets = targets - target_mean
    gram = centered_features.T @ centered_features
    regularized = gram + weight * np.eye(gram.shape[0])
    weights = np.linalg.solve(
        regularized,
        centered_features.T @ centered_targets,
    )
    fitted = centered_features @ weights + target_mean
    residual = centered_targets - (fitted - target_mean)
    total = float(np.square(centered_targets).sum())
    unexplained = float(np.square(residual).sum())
    r2 = 1.0 - unexplained / total
    return weights, feature_mean, target_mean, r2


def predict(
    features: np.ndarray,
    weights: np.ndarray,
    feature_mean: np.ndarray,
    target_mean: np.ndarray,
) -> np.ndarray:
    return (features - feature_mean) @ weights + target_mean


def cross_validated_r2(
    features: np.ndarray,
    targets: np.ndarray,
    *,
    weight: float,
    folds: int,
) -> float:
    if folds < 2 or folds > features.shape[0]:
        raise ValueError("Invalid cross-validation fold count")
    indices = np.arange(features.shape[0])
    predictions = np.empty_like(targets)
    for fold in range(folds):
        test_mask = indices % folds == fold
        train_mask = ~test_mask
        weights, feature_mean, target_mean, _ = fit_ridge(
            features[train_mask],
            targets[train_mask],
            weight=weight,
        )
        predictions[test_mask] = predict(
            features[test_mask],
            weights,
            feature_mean,
            target_mean,
        )
    centered = targets - targets.mean(axis=0)
    total = float(np.square(centered).sum())
    residual = targets - predictions
    return 1.0 - float(np.square(residual).sum()) / total


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-nt", required=True)
    parser.add_argument("--source-ecapa", required=True)
    parser.add_argument("--target-nt", required=True)
    parser.add_argument("--target-ecapa", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--ridge-weight", type=float, default=1.0)
    parser.add_argument("--cv-folds", type=int, default=5)
    parser.add_argument(
        "--strengths",
        type=float,
        nargs="+",
        default=[0.25, 0.5, 1.0],
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.strengths or any(value <= 0.0 for value in args.strengths):
        raise ValueError("All residual strengths must be positive")
    source_nt = load_archive(args.source_nt)
    source_ecapa = load_archive(args.source_ecapa)
    target_nt = load_archive(args.target_nt)
    target_ecapa = load_archive(args.target_ecapa)

    paired_keys = sorted(set(source_nt) & set(source_ecapa))
    if len(paired_keys) < 32:
        raise ValueError(f"Too few paired source speakers: {len(paired_keys)}")
    missing_target_ecapa = sorted(set(target_nt) - set(target_ecapa))
    if missing_target_ecapa:
        raise ValueError(
            f"Missing ECAPA targets: {missing_target_ecapa[:10]}"
        )

    source_ecapa_matrix = np.stack([source_ecapa[key] for key in paired_keys])
    source_nt_matrix = np.stack([source_nt[key] for key in paired_keys])
    weights, feature_mean, target_mean, r2 = fit_ridge(
        source_ecapa_matrix,
        source_nt_matrix,
        weight=args.ridge_weight,
    )
    cv_r2 = cross_validated_r2(
        source_ecapa_matrix,
        source_nt_matrix,
        weight=args.ridge_weight,
        folds=args.cv_folds,
    )

    target_keys = sorted(target_nt)
    target_nt_matrix = l2_normalize(
        np.stack([target_nt[key] for key in target_keys])
    )
    predicted_nt = predict(
        np.stack([target_ecapa[key] for key in target_keys]),
        weights,
        feature_mean,
        target_mean,
    )
    projection = (predicted_nt * target_nt_matrix).sum(
        axis=1,
        keepdims=True,
    )
    residual = predicted_nt - projection * target_nt_matrix
    residual_norms = np.linalg.norm(residual, axis=1)

    output_root = Path(args.out_dir)
    output_root.mkdir(parents=True, exist_ok=True)
    root_stats = {
        "paired_source_speakers": len(paired_keys),
        "target_speakers": len(target_keys),
        "ridge_weight": args.ridge_weight,
        "ridge_train_r2": r2,
        "ridge_cv_r2": cv_r2,
        "residual_norm_mean": float(residual_norms.mean()),
        "residual_norm_median": float(np.median(residual_norms)),
        "residual_norm_min": float(residual_norms.min()),
        "residual_norm_max": float(residual_norms.max()),
        "strengths": {},
    }
    for strength in args.strengths:
        combined = l2_normalize(
            target_nt_matrix + float(strength) * residual
        )
        cosine_to_original = (combined * target_nt_matrix).sum(axis=1)
        values = {
            key: combined[index].astype(np.float32)
            for index, key in enumerate(target_keys)
        }
        label = f"residual_{str(strength).replace('.', 'p')}"
        destination = output_root / f"{label}.npz"
        np.savez(destination, **values)
        root_stats["strengths"][label] = {
            "npz": str(destination),
            "cosine_to_original_mean": float(cosine_to_original.mean()),
            "cosine_to_original_min": float(cosine_to_original.min()),
            "cosine_to_original_max": float(cosine_to_original.max()),
        }
        print(f"wrote {destination} keys={len(values)}")

    report = output_root / "mapping_report.json"
    report.write_text(
        json.dumps(root_stats, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(root_stats, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
