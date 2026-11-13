"""Build a deterministic LibriSpeech ASV/WER evaluation subset."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

import numpy as np


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--speaker-embeddings", required=True)
    parser.add_argument("--target-embeddings", default=None)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--utts-per-speaker", type=int, default=2)
    parser.add_argument("--max-speakers", type=int, default=40)
    parser.add_argument("--seed", type=int, default=20261101)
    parser.add_argument(
        "--target-map-mode",
        choices=["speaker", "utterance"],
        default="speaker",
    )
    return parser.parse_args()


def transcript_maps(rows: list[dict]) -> dict[str, dict[str, str]]:
    by_chapter = defaultdict(list)
    for row in rows:
        by_chapter[str(Path(row["audio"]).parent)].append(row["audio"])
    output = {}
    for chapter, files in by_chapter.items():
        trans_files = sorted(Path(chapter).glob("*.trans.txt"))
        if not trans_files:
            continue
        mapping = {}
        with trans_files[0].open(encoding="utf-8") as handle:
            for line in handle:
                utterance_id, text = line.strip().split(" ", 1)
                mapping[utterance_id] = text
        output[chapter] = mapping
    return output


def main() -> int:
    args = parse_args()
    with open(args.manifest, encoding="utf-8") as handle:
        rows = [json.loads(line) for line in handle]
    by_speaker = defaultdict(list)
    for row in rows:
        by_speaker[row["speaker"]].append(row)
    maps = transcript_maps(rows)

    speakers = sorted(by_speaker)[: args.max_speakers]
    selected = []
    for speaker in speakers:
        candidates = sorted(
            by_speaker[speaker],
            key=lambda row: abs(row["seconds"] - 4.0),
        )
        for row in candidates[: args.utts_per_speaker]:
            chapter = str(Path(row["audio"]).parent)
            utterance_id = Path(row["audio"]).stem
            text = maps.get(chapter, {}).get(utterance_id)
            if not text:
                continue
            selected.append({**row, "text": text})

    embeddings = np.load(
        args.target_embeddings or args.speaker_embeddings
    )
    all_target_speakers = sorted(embeddings.files)
    target_speakers = list(all_target_speakers)
    rng = np.random.default_rng(args.seed)
    rng.shuffle(target_speakers)
    target_map = {}
    for speaker in speakers:
        candidates = [target for target in target_speakers if target != speaker]
        if candidates:
            target = candidates.pop()
            target_speakers.remove(target)
        else:
            fallback = [
                target
                for target in all_target_speakers
                if target != speaker
            ]
            target = str(rng.choice(fallback))
        target_map[speaker] = str(target)

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    with (out / "eval_source.jsonl").open("w", encoding="utf-8") as handle:
        for row in selected:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")
    (out / "target_map.json").write_text(
        json.dumps(target_map, indent=2), encoding="utf-8"
    )
    if args.target_map_mode == "utterance":
        utterance_map = {}
        rows_by_speaker = defaultdict(list)
        for row in selected:
            rows_by_speaker[row["speaker"]].append(row)
        utterance_rng = np.random.default_rng(args.seed + 1)
        for speaker in speakers:
            pool = list(all_target_speakers)
            utterance_rng.shuffle(pool)
            for index, row in enumerate(rows_by_speaker[speaker]):
                utterance_map[row["audio"]] = str(pool[index % len(pool)])
        (out / "target_map_utterance.json").write_text(
            json.dumps(utterance_map, indent=2), encoding="utf-8"
        )
    summary = {
        "utterances": len(selected),
        "speakers": len({row["speaker"] for row in selected}),
        "target_speakers": len(set(target_map.values())),
        "utterance_targets": (
            len(utterance_map) if args.target_map_mode == "utterance" else 0
        ),
    }
    (out / "eval_summary.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8"
    )
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
