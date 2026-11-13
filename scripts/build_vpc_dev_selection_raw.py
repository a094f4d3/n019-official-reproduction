#!/usr/bin/env python3
"""Build a speaker-balanced raw VPC libri_dev subset for MOS selection."""

from __future__ import annotations

import argparse
import json
import shutil
from collections import defaultdict
from pathlib import Path

import soundfile as sf


def parse_transcripts(root: Path) -> dict[str, str]:
    transcripts: dict[str, str] = {}
    for path in root.rglob("*.trans.txt"):
        for raw in path.read_text(encoding="utf-8").splitlines():
            if not raw.strip():
                continue
            identifier, text = raw.split(" ", 1)
            if identifier in transcripts:
                raise SystemExit(f"Duplicate transcript ID: {identifier}")
            transcripts[identifier] = text.strip().upper()
    return transcripts


def nearest(items: list[dict], fraction: float) -> dict:
    index = round((len(items) - 1) * fraction)
    return items[index]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vpc-wav-root", required=True, type=Path)
    parser.add_argument("--librispeech-dev-root", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--speakers", type=int, default=40)
    parser.add_argument("--base-per-speaker", type=int, default=2)
    parser.add_argument("--extra-speakers", type=int, default=20)
    args = parser.parse_args()

    if args.out.exists():
        raise SystemExit(f"Output already exists: {args.out}")
    transcripts = parse_transcripts(args.librispeech_dev_root)
    by_speaker: dict[str, list[dict]] = defaultdict(list)
    for wav in sorted(args.vpc_wav_root.rglob("*.wav")):
        identifier = wav.stem
        speaker = identifier.split("-", 1)[0]
        info = sf.info(str(wav))
        if info.frames <= 0 or info.samplerate <= 0:
            raise SystemExit(f"Invalid audio metadata: {wav}")
        by_speaker[speaker].append(
            {
                "id": identifier,
                "speaker": speaker,
                "audio": wav,
                "seconds": info.frames / info.samplerate,
                "sample_rate": info.samplerate,
            }
        )

    speakers = sorted(by_speaker)
    if len(speakers) != args.speakers:
        raise SystemExit(
            f"Expected {args.speakers} speakers, found {len(speakers)}"
        )
    if args.base_per_speaker != 2:
        raise SystemExit("This selection script currently expects two base items")

    selected: list[dict] = []
    for speaker_index, speaker in enumerate(speakers):
        items = sorted(by_speaker[speaker], key=lambda row: row["id"])
        if len(items) < 3:
            raise SystemExit(f"Speaker {speaker} has fewer than three utterances")
        fractions = [0.25, 0.75]
        if speaker_index < args.extra_speakers:
            fractions.append(0.50)
        for fraction in fractions:
            row = nearest(items, fraction)
            if row["id"] not in {item["id"] for item in selected}:
                selected.append(row)

    if len(selected) != 100:
        raise SystemExit(f"Expected 100 selected utterances, got {len(selected)}")
    selected.sort(key=lambda row: row["id"])

    args.out.mkdir(parents=True)
    audio_dir = args.out / "audio"
    audio_dir.mkdir()
    manifest = []
    for row in selected:
        identifier = row["id"]
        destination = audio_dir / f"{identifier}.wav"
        shutil.copy2(row["audio"], destination)
        transcript = transcripts.get(identifier)
        if not transcript:
            raise SystemExit(f"Missing transcript for {identifier}")
        destination.with_suffix(".normalized.txt").write_text(
            transcript + "\n",
            encoding="utf-8",
        )
        manifest.append(
            {
                "id": identifier,
                "speaker": row["speaker"],
                "dataset": "vpc2024-libri_dev",
                "split": "libri_dev",
                "audio": str((args.out / "audio" / destination.name).resolve()),
                "relative_path": destination.name,
                "seconds": row["seconds"],
                "sample_rate": row["sample_rate"],
                "channels": 1,
                "text": transcript,
            }
        )

    manifest_path = args.out / "manifest.jsonl"
    manifest_path.write_text(
        "\n".join(json.dumps(row, sort_keys=True) for row in manifest) + "\n",
        encoding="utf-8",
    )
    speaker_counts = {
        speaker: sum(row["speaker"] == speaker for row in manifest)
        for speaker in speakers
    }
    summary = {
        "rows": len(manifest),
        "speakers": len(speaker_counts),
        "speaker_counts": speaker_counts,
        "mean_seconds": sum(row["seconds"] for row in manifest) / len(manifest),
        "min_seconds": min(row["seconds"] for row in manifest),
        "max_seconds": max(row["seconds"] for row in manifest),
    }
    (args.out / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
