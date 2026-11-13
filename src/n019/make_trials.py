"""Create aligned positive/negative ASV trial manifests."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path


def read_jsonl(path: str) -> list[dict]:
    with open(path, encoding="utf-8") as handle:
        return [json.loads(line) for line in handle]


def write_jsonl(path: Path, rows: list[dict]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--anon", default=None)
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()
    source_rows = read_jsonl(args.source)
    if args.anon:
        anon_rows = read_jsonl(args.anon)
        anon_by_source = {row["source_audio"]: row for row in anon_rows}
    else:
        anon_by_source = None

    by_speaker = defaultdict(list)
    for row in source_rows:
        by_speaker[row["speaker"]].append(row)
    speakers = sorted(speaker for speaker, rows in by_speaker.items() if len(rows) >= 2)
    if len(speakers) < 2:
        raise ValueError("At least two speakers with two utterances are required")

    enroll_original = []
    trial_original = []
    enroll_anon = []
    trial_anon = []
    trial_speakers = []
    for index, speaker in enumerate(speakers):
        rows = sorted(by_speaker[speaker], key=lambda row: row["audio"])
        enrollment = rows[0]
        positive_trial = rows[1]
        for label, trial_row in [
            (1, positive_trial),
            (0, sorted(by_speaker[speakers[(index + 1) % len(speakers)]], key=lambda row: row["audio"])[1]),
        ]:
            enroll_original.append(enrollment)
            trial_original.append(trial_row)
            if anon_by_source is not None:
                enroll_anon.append(anon_by_source[enrollment["audio"]])
                trial_anon.append(anon_by_source[trial_row["audio"]])
            trial_speakers.append(label)

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    write_jsonl(out / "enroll_original.jsonl", enroll_original)
    write_jsonl(out / "trial_original.jsonl", trial_original)
    if anon_by_source is not None:
        write_jsonl(out / "enroll_anon.jsonl", enroll_anon)
        write_jsonl(out / "trial_anon.jsonl", trial_anon)
    (out / "trial_summary.json").write_text(
        json.dumps(
            {
                "speakers": len(speakers),
                "trials": len(trial_speakers),
                "positive": sum(trial_speakers),
                "negative": len(trial_speakers) - sum(trial_speakers),
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"Wrote {len(trial_speakers)} trials to {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
