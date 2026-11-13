#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from pathlib import Path

import soundfile as sf


EXPECTED = {
    "libri_test_enrolls/wav.scp": 438,
    "libri_test_trials_f/wav.scp": 734,
    "libri_test_trials_f/trials": 11744,
    "libri_test_trials_m/wav.scp": 762,
    "libri_test_trials_m/trials": 9906,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify a materialized VPC2024 LibriSpeech dev/test set."
    )
    parser.add_argument("--vpc-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--duration-tolerance", type=float, default=0.05)
    parser.add_argument(
        "--subset",
        choices=["test", "dev", "all"],
        default="all",
        help="Restrict WAV checks to the test, dev, or both manifest sets.",
    )
    return parser.parse_args()


def count_lines(path: Path) -> int:
    with path.open("r", encoding="utf-8") as handle:
        return sum(1 for line in handle if line.strip())


def read_pairs(path: Path) -> dict[str, Path]:
    pairs: dict[str, Path] = {}
    with path.open("r", encoding="utf-8") as handle:
        for line_number, raw_line in enumerate(handle, 1):
            line = raw_line.strip()
            if not line:
                continue
            fields = line.split(maxsplit=1)
            if len(fields) != 2:
                raise ValueError(f"Invalid line {path}:{line_number}")
            key, relative_path = fields
            pairs[key] = Path(relative_path)
    return pairs


def read_durations(root: Path) -> dict[str, float]:
    durations: dict[str, float] = {}
    for path in root.glob("libri_*_*/utt2dur"):
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                fields = line.split()
                if len(fields) >= 2:
                    durations[fields[0]] = float(fields[1])
    return durations


def main() -> int:
    args = parse_args()
    root = args.vpc_root.resolve()
    data_root = root / "data"
    errors: list[str] = []
    counts: dict[str, int] = {}

    for relative_path, expected in EXPECTED.items():
        path = data_root / relative_path
        actual = count_lines(path)
        counts[relative_path] = actual
        if actual != expected:
            errors.append(f"{relative_path}: {actual} != {expected}")

    test_pairs: dict[str, Path] = {}
    dev_pairs: dict[str, Path] = {}
    for manifest_dir in sorted(data_root.glob("libri_*_*")):
        wav_scp = manifest_dir / "wav.scp"
        if not wav_scp.is_file():
            continue
        is_test = manifest_dir.name.startswith("libri_test_")
        if args.subset == "test" and not is_test:
            continue
        if args.subset == "dev" and is_test:
            continue
        target = test_pairs if is_test else dev_pairs
        for utt_id, relative_path in read_pairs(wav_scp).items():
            previous = target.get(utt_id)
            if previous is not None and previous != relative_path:
                errors.append(f"Conflicting target for {utt_id}")
            target[utt_id] = relative_path

    counts["test_unique_wav"] = len(test_pairs)
    counts["dev_unique_wav"] = len(dev_pairs)
    if args.subset in {"test", "all"} and len(test_pairs) != 1934:
        errors.append(f"test_unique_wav: {len(test_pairs)} != 1934")

    durations = read_durations(data_root)
    formats: dict[str, int] = {}
    checked = 0
    selected_pairs = {}
    if args.subset in {"test", "all"}:
        selected_pairs.update(test_pairs)
    if args.subset in {"dev", "all"}:
        selected_pairs.update(dev_pairs)
    for utt_id, relative_path in selected_pairs.items():
        path = root / relative_path
        if not path.is_file():
            errors.append(f"Missing WAV for {utt_id}: {path}")
            continue
        try:
            info = sf.info(str(path))
        except Exception as exc:
            errors.append(f"Unreadable WAV for {utt_id}: {exc!r}")
            continue
        checked += 1
        format_key = f"{info.samplerate}Hz/{info.channels}ch/{info.subtype}"
        formats[format_key] = formats.get(format_key, 0) + 1
        if (info.samplerate, info.channels, info.subtype) != (16000, 1, "PCM_16"):
            errors.append(f"Wrong format for {utt_id}: {format_key}")
        expected_duration = durations.get(utt_id)
        if expected_duration is None:
            errors.append(f"Missing utt2dur for {utt_id}")
        elif abs(info.duration - expected_duration) > args.duration_tolerance:
            errors.append(
                f"Duration mismatch for {utt_id}: "
                f"{info.duration} vs {expected_duration}"
            )

    counts["wav_checked"] = checked
    counts["trial_pairs"] = (
        counts["libri_test_trials_f/trials"]
        + counts["libri_test_trials_m/trials"]
    )
    if counts["trial_pairs"] != 21650:
        errors.append(f"trial_pairs: {counts['trial_pairs']} != 21650")

    report = {
        "ok": not errors,
        "vpc_root": str(root),
        "subset": args.subset,
        "counts": counts,
        "formats": formats,
        "duration_tolerance_seconds": args.duration_tolerance,
        "errors": errors,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(report, indent=2, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report, indent=2, ensure_ascii=True))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
