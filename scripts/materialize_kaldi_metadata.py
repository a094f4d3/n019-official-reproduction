#!/usr/bin/env python3
"""Create VPC-compatible Kaldi metadata from a validated manifest."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


def read_manifest(path: Path) -> list[dict]:
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not rows:
        raise ValueError(f"Empty manifest: {path}")
    identifiers = [str(row["id"]) for row in rows]
    if len(identifiers) != len(set(identifiers)):
        raise ValueError(f"Duplicate utterance IDs in {path}")
    return rows


def write_atomic(path: Path, lines: list[str]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--dataset-dir", required=True)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()
    manifest = Path(args.manifest).resolve()
    dataset_dir = Path(args.dataset_dir).resolve()
    if not dataset_dir.is_dir():
        raise FileNotFoundError(dataset_dir)
    names = ("wav.scp", "utt2spk", "spk2gender", "text", "utt2dur", "spk2utt")
    existing = [name for name in names if (dataset_dir / name).exists()]
    if existing and not args.overwrite:
        raise FileExistsError(
            f"Metadata already exists in {dataset_dir}: {existing}"
        )
    rows = read_manifest(manifest)
    wav_lines = []
    utt2spk = []
    texts = []
    durations = []
    speakers = {}
    speaker_utterances: dict[str, list[str]] = {}
    for row in rows:
        identifier = str(row["id"])
        speaker = str(row["speaker"])
        audio = Path(row["audio"]).resolve()
        if not audio.is_file():
            raise FileNotFoundError(audio)
        wav_lines.append(f"{identifier} {audio}")
        utt2spk.append(f"{identifier} {speaker}")
        texts.append(f"{identifier} {row.get('text', '').strip()}")
        if row.get("seconds") is not None:
            durations.append(f"{identifier} {float(row['seconds']):.6f}")
        gender = str(row.get("gender") or "").strip()
        if gender:
            previous = speakers.setdefault(speaker, gender)
            if previous != gender:
                raise ValueError(
                    f"Speaker {speaker} has inconsistent gender labels"
                )
        speaker_utterances.setdefault(speaker, []).append(identifier)
    spk2gender = [
        f"{speaker} {gender}"
        for speaker, gender in sorted(speakers.items())
    ]
    spk2utt = [
        f"{speaker} {' '.join(utterances)}"
        for speaker, utterances in sorted(speaker_utterances.items())
    ]
    write_atomic(dataset_dir / "wav.scp", wav_lines)
    write_atomic(dataset_dir / "utt2spk", utt2spk)
    write_atomic(dataset_dir / "spk2gender", spk2gender)
    write_atomic(dataset_dir / "text", texts)
    write_atomic(dataset_dir / "utt2dur", durations)
    write_atomic(dataset_dir / "spk2utt", spk2utt)
    print(
        json.dumps(
            {
                "dataset_dir": str(dataset_dir),
                "utterances": len(rows),
                "speakers": len(speaker_utterances),
                "files": list(names),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
