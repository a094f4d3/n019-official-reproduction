"""Build official-corpus manifests without substituting other datasets."""

from __future__ import annotations

import argparse
import hashlib
import time
from collections import defaultdict
from pathlib import Path

import soundfile as sf

from n019.manifest import write_json, write_jsonl


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def discover(
    root: Path,
    *,
    dataset: str,
    split: str,
    speaker_position: str,
    id_prefix: str,
) -> list[dict]:
    root = root.resolve()
    if not root.is_dir():
        raise FileNotFoundError(root)
    files = sorted(
        [
            *root.rglob("*.flac"),
            *root.rglob("*.wav"),
        ]
    )
    if not files:
        raise ValueError(f"No audio files under {root}")
    rows = []
    used_ids: set[str] = set()
    started = time.time()
    for index, path in enumerate(files, 1):
        relative = path.relative_to(root)
        parts = relative.parts
        if speaker_position == "first":
            speaker = parts[0]
        elif speaker_position == "third_from_end":
            speaker = parts[-3]
        else:
            raise ValueError(f"Unknown speaker position: {speaker_position}")
        identifier = f"{id_prefix}:{path.stem}"
        if identifier in used_ids:
            raise ValueError(f"Duplicate utterance ID: {identifier}")
        used_ids.add(identifier)
        info = sf.info(str(path))
        rows.append(
            {
                "id": identifier,
                "dataset": dataset,
                "split": split,
                "audio": str(path),
                "speaker": speaker,
                "relative_path": str(relative),
                "sample_rate": int(info.samplerate),
                "channels": int(info.channels),
                "frames": int(info.frames),
                "seconds": float(info.frames / info.samplerate),
                "sha256": sha256_file(path),
            }
        )
        if index % 100 == 0:
            print(
                f"manifest_scan dataset={dataset} split={split} "
                f"files={index}/{len(files)} elapsed={time.time() - started:.1f}s",
                flush=True,
            )
    return rows


def summarize(rows: list[dict]) -> dict:
    speakers: dict[str, list[float]] = defaultdict(list)
    for row in rows:
        speakers[row["speaker"]].append(row["seconds"])
    return {
        "utterances": len(rows),
        "speakers": len(speakers),
        "hours": sum(row["seconds"] for row in rows) / 3600,
        "sample_rates": sorted({row["sample_rate"] for row in rows}),
        "channels": sorted({row["channels"] for row in rows}),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create manifests for the three N019 training corpora."
    )
    parser.add_argument("--librispeech-train", required=True)
    parser.add_argument("--libritts-train", required=True)
    parser.add_argument("--libritts-target", required=True)
    parser.add_argument("--out", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    out = Path(args.out)
    manifests = {
        "librispeech_train_clean_100": discover(
            Path(args.librispeech_train),
            dataset="librispeech",
            split="train-clean-100",
            speaker_position="first",
            id_prefix="ls100",
        ),
        "libritts_train_clean_100": discover(
            Path(args.libritts_train),
            dataset="libritts",
            split="train-clean-100",
            speaker_position="third_from_end",
            id_prefix="tts100",
        ),
        "libritts_train_other_500": discover(
            Path(args.libritts_target),
            dataset="libritts",
            split="train-other-500",
            speaker_position="third_from_end",
            id_prefix="tts500",
        ),
    }
    summary = {}
    for name, rows in manifests.items():
        write_jsonl(out / f"{name}.jsonl", rows)
        summary[name] = summarize(rows)
    write_json(out / "dataset_summary.json", summary)
    print(summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
