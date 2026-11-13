"""Pool selected target-utterance embeddings to a speaker-level proxy."""

from __future__ import annotations

import argparse
import json
import os
from collections import defaultdict
from pathlib import Path

import numpy as np

from n019.manifest import iter_jsonl, sha256_file, write_json


def load_embedding_archive(path: str | Path) -> dict[str, np.ndarray]:
    archive = np.load(path, allow_pickle=False)
    values = {
        str(key): np.asarray(archive[key], dtype=np.float32)
        for key in archive.files
    }
    archive.close()
    if not values:
        raise ValueError(f"Embedding archive is empty: {path}")
    dimensions = {int(value.size) for value in values.values()}
    if len(dimensions) != 1:
        raise ValueError(f"Mixed embedding dimensions: {sorted(dimensions)}")
    if any(not np.isfinite(value).all() for value in values.values()):
        raise ValueError(f"Embedding archive contains non-finite values: {path}")
    return values


def collect_target_groups(
    target_map_path: str | Path,
) -> tuple[dict[str, str], dict[str, set[str]]]:
    target_to_speaker: dict[str, str] = {}
    speaker_to_targets: dict[str, set[str]] = defaultdict(set)
    for row in iter_jsonl(target_map_path):
        target_id = str(row["target_id"])
        target_speaker = str(row["target_speaker"])
        previous = target_to_speaker.get(target_id)
        if previous is not None and previous != target_speaker:
            raise ValueError(
                f"Target {target_id} maps to both {previous} and {target_speaker}"
            )
        target_to_speaker[target_id] = target_speaker
        speaker_to_targets[target_speaker].add(target_id)
    if not target_to_speaker:
        raise ValueError("Target map is empty")
    return target_to_speaker, dict(speaker_to_targets)


def pool_target_embeddings(
    embeddings: dict[str, np.ndarray],
    target_to_speaker: dict[str, str],
    speaker_to_targets: dict[str, set[str]],
    *,
    key_mode: str,
) -> tuple[dict[str, np.ndarray], dict]:
    if key_mode not in {"target_id", "target_speaker"}:
        raise ValueError("key_mode must be target_id or target_speaker")
    missing = sorted(set(target_to_speaker) - set(embeddings))
    if missing:
        raise KeyError(
            f"{len(missing)} target IDs have no embedding; first={missing[:5]}"
        )
    methods: dict[str, str] = {}
    group_counts: dict[str, int] = {}
    speaker_vectors: dict[str, np.ndarray] = {}
    for speaker, target_ids in sorted(speaker_to_targets.items()):
        available = sorted(target_ids & set(embeddings))
        if not available:
            raise KeyError(f"No embeddings for target speaker {speaker}")
        stacked = np.stack([embeddings[target_id] for target_id in available], axis=0)
        mean = stacked.mean(axis=0, dtype=np.float64).astype(np.float32)
        if not np.isfinite(mean).all():
            raise ValueError(f"Non-finite pooled embedding for speaker {speaker}")
        norm = float(np.linalg.norm(mean))
        if norm <= 1e-12:
            raise ValueError(f"Zero-norm pooled embedding for speaker {speaker}")
        speaker_vectors[speaker] = (mean / norm).astype(np.float32)
        group_counts[speaker] = len(available)
        methods[speaker] = "mean_then_l2"

    if key_mode == "target_speaker":
        output = speaker_vectors
    else:
        output = {
            target_id: speaker_vectors[speaker]
            for target_id, speaker in sorted(target_to_speaker.items())
        }
    dimensions = {int(value.size) for value in output.values()}
    if len(dimensions) != 1:
        raise ValueError(f"Pooled output has mixed dimensions: {sorted(dimensions)}")
    norms = [float(np.linalg.norm(value)) for value in output.values()]
    if min(norms) < 1.0 - 1e-5 or max(norms) > 1.0 + 1e-5:
        raise ValueError(
            f"Pooled embeddings are not unit norm: min={min(norms)} max={max(norms)}"
        )
    report = {
        "method": "mean_then_l2",
        "key_mode": key_mode,
        "dimension": dimensions.pop(),
        "target_ids": len(target_to_speaker),
        "target_speakers": len(speaker_to_targets),
        "output_keys": len(output),
        "group_size_min": min(group_counts.values()),
        "group_size_max": max(group_counts.values()),
        "group_size_mean": sum(group_counts.values()) / len(group_counts),
        "norm_min": min(norms),
        "norm_max": max(norms),
        "group_size_histogram": {
            str(size): sum(
                1 for value in group_counts.values() if value == size
            )
            for size in sorted(set(group_counts.values()))
        },
    }
    return output, report


def save_npz_atomic(path: str | Path, values: dict[str, np.ndarray]) -> None:
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    with temporary.open("wb") as handle:
        np.savez(handle, **values)
    os.replace(temporary, destination)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Mean-pool the selected target-utterance W-PRO/ECAPA embeddings "
            "within each target speaker, then L2-normalize."
        )
    )
    parser.add_argument("--embeddings", required=True)
    parser.add_argument("--target-map", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument(
        "--key-mode",
        choices=["target_id", "target_speaker"],
        default="target_speaker",
    )
    parser.add_argument("--report", default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    embeddings = load_embedding_archive(args.embeddings)
    target_to_speaker, speaker_to_targets = collect_target_groups(args.target_map)
    pooled, report = pool_target_embeddings(
        embeddings,
        target_to_speaker,
        speaker_to_targets,
        key_mode=args.key_mode,
    )
    save_npz_atomic(args.out, pooled)
    summary = {
        **report,
        "source_embeddings": str(Path(args.embeddings).resolve()),
        "source_embeddings_sha256": sha256_file(args.embeddings),
        "target_map": str(Path(args.target_map).resolve()),
        "target_map_sha256": sha256_file(args.target_map),
        "output": str(Path(args.out).resolve()),
        "output_sha256": sha256_file(args.out),
    }
    report_path = (
        Path(args.report)
        if args.report
        else Path(args.out).with_suffix(".metadata.json")
    )
    write_json(report_path, summary)
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
