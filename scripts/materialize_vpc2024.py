#!/usr/bin/env python3

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import soundfile as sf


@dataclass(frozen=True)
class Item:
    utt_id: str
    split: str
    target_path: Path
    source_path: Path
    expected_duration: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Materialize VPC2024 LibriSpeech utterances from official manifests."
    )
    parser.add_argument(
        "--vpc-root",
        type=Path,
        required=True,
        help="Directory containing VPC data/ and exp/.",
    )
    parser.add_argument(
        "--librispeech-root",
        type=Path,
        required=True,
        help="Directory containing test-clean/ and dev-clean/.",
    )
    parser.add_argument("--ffmpeg", type=Path, required=True)
    parser.add_argument("--audit-dir", type=Path, required=True)
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument(
        "--subset",
        choices=["test", "dev", "all"],
        default="all",
        help="Restrict materialization to VPC test or dev manifests.",
    )
    parser.add_argument(
        "--duration-tolerance",
        type=float,
        default=0.05,
        help="Maximum allowed absolute duration error in seconds.",
    )
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_kv_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    with path.open("r", encoding="utf-8") as handle:
        for line_number, raw_line in enumerate(handle, 1):
            line = raw_line.strip()
            if not line:
                continue
            fields = line.split(maxsplit=1)
            if len(fields) != 2:
                raise ValueError(f"Invalid line {path}:{line_number}: {line!r}")
            key, value = fields
            if key in values and values[key] != value:
                raise ValueError(f"Conflicting value for {key} in {path}")
            values[key] = value
    return values


def find_source(librispeech_root: Path, split: str, utt_id: str) -> Path:
    parts = utt_id.split("-")
    if len(parts) != 3:
        raise ValueError(f"Unexpected LibriSpeech utterance ID: {utt_id}")
    split_name = "test-clean" if split == "test" else "dev-clean"
    source = (
        librispeech_root
        / split_name
        / parts[0]
        / parts[1]
        / f"{utt_id}.flac"
    )
    if source.is_file():
        return source

    chapter_dir = librispeech_root / split_name / parts[0] / parts[1]
    matches = sorted(chapter_dir.glob(f"{utt_id}.flac"))
    if len(matches) == 1:
        return matches[0]
    raise FileNotFoundError(f"Cannot resolve {utt_id} under {chapter_dir}")


def collect_items(
    vpc_root: Path,
    librispeech_root: Path,
    limit: int,
    subset: str,
) -> tuple[list[Item], dict[str, float]]:
    data_root = vpc_root / "data"
    manifest_dirs = sorted(
        path
        for path in data_root.iterdir()
        if path.is_dir()
        and path.name.startswith(("libri_dev_", "libri_test_"))
        and (path / "wav.scp").is_file()
    )
    if not manifest_dirs:
        raise FileNotFoundError(f"No LibriSpeech VPC manifests under {data_root}")
    if subset == "test":
        manifest_dirs = [
            path for path in manifest_dirs if path.name.startswith("libri_test_")
        ]
    elif subset == "dev":
        manifest_dirs = [
            path for path in manifest_dirs if path.name.startswith("libri_dev_")
        ]
    if not manifest_dirs:
        raise FileNotFoundError(f"No VPC manifests selected for subset={subset}")

    durations: dict[str, float] = {}
    for manifest_dir in manifest_dirs:
        duration_path = manifest_dir / "utt2dur"
        if not duration_path.is_file():
            continue
        for utt_id, value in read_kv_file(duration_path).items():
            duration = float(value)
            previous = durations.get(utt_id)
            if previous is not None and abs(previous - duration) > 0.001:
                raise ValueError(
                    f"Conflicting durations for {utt_id}: {previous} vs {duration}"
                )
            durations[utt_id] = duration

    items_by_target: dict[Path, Item] = {}
    for manifest_dir in manifest_dirs:
        split = "test" if manifest_dir.name.startswith("libri_test_") else "dev"
        with (manifest_dir / "wav.scp").open("r", encoding="utf-8") as handle:
            for line_number, raw_line in enumerate(handle, 1):
                line = raw_line.strip()
                if not line:
                    continue
                fields = line.split(maxsplit=1)
                if len(fields) != 2:
                    raise ValueError(
                        f"Invalid line {manifest_dir / 'wav.scp'}:{line_number}"
                    )
                utt_id, relative_target = fields
                if utt_id not in durations:
                    raise KeyError(f"Missing utt2dur entry for {utt_id}")
                target_path = (vpc_root / relative_target).resolve()
                source_path = find_source(librispeech_root, split, utt_id)
                item = Item(
                    utt_id=utt_id,
                    split=split,
                    target_path=target_path,
                    source_path=source_path,
                    expected_duration=durations[utt_id],
                )
                previous = items_by_target.get(target_path)
                if previous is not None and previous != item:
                    raise ValueError(f"Conflicting target mapping for {target_path}")
                items_by_target[target_path] = item

    items = sorted(items_by_target.values(), key=lambda item: str(item.target_path))
    if limit:
        items = items[:limit]
    return items, durations


def inspect_wav(path: Path) -> tuple[float, int, int, str]:
    info = sf.info(str(path))
    return info.duration, info.samplerate, info.channels, info.subtype


def is_valid_wav(path: Path, expected_duration: float, tolerance: float) -> bool:
    if not path.is_file() or path.stat().st_size == 0:
        return False
    try:
        duration, sample_rate, channels, subtype = inspect_wav(path)
    except Exception:
        return False
    return (
        sample_rate == 16000
        and channels == 1
        and subtype == "PCM_16"
        and abs(duration - expected_duration) <= tolerance
    )


def materialize_one(
    item: Item,
    ffmpeg: Path,
    tolerance: float,
) -> dict[str, object]:
    if is_valid_wav(item.target_path, item.expected_duration, tolerance):
        status = "resumed"
    else:
        item.target_path.parent.mkdir(parents=True, exist_ok=True)
        fd, temporary_name = tempfile.mkstemp(
            prefix=f".{item.utt_id}.",
            suffix=".wav",
            dir=item.target_path.parent,
        )
        os.close(fd)
        temporary_path = Path(temporary_name)
        try:
            command = [
                str(ffmpeg),
                "-nostdin",
                "-y",
                "-loglevel",
                "error",
                "-i",
                str(item.source_path),
                "-ar",
                "16000",
                "-ac",
                "1",
                "-c:a",
                "pcm_s16le",
                str(temporary_path),
            ]
            subprocess.run(command, check=True)
            if not is_valid_wav(
                temporary_path,
                item.expected_duration,
                tolerance,
            ):
                raise ValueError(
                    f"Converted WAV failed metadata or duration check: {item.utt_id}"
                )
            temporary_path.replace(item.target_path)
            status = "created"
        finally:
            temporary_path.unlink(missing_ok=True)

    duration, sample_rate, channels, subtype = inspect_wav(item.target_path)
    return {
        "utt_id": item.utt_id,
        "split": item.split,
        "target_path": str(item.target_path),
        "source_path": str(item.source_path),
        "source_sha256": sha256_file(item.source_path),
        "target_sha256": sha256_file(item.target_path),
        "expected_duration": item.expected_duration,
        "duration": duration,
        "sample_rate": sample_rate,
        "channels": channels,
        "subtype": subtype,
        "status": status,
    }


def main() -> int:
    args = parse_args()
    args.vpc_root = args.vpc_root.resolve()
    args.librispeech_root = args.librispeech_root.resolve()
    args.audit_dir = args.audit_dir.resolve()
    args.audit_dir.mkdir(parents=True, exist_ok=True)

    items, durations = collect_items(
        args.vpc_root,
        args.librispeech_root,
        args.limit,
        args.subset,
    )
    if not items:
        raise RuntimeError("No utterances selected")

    ffmpeg_version = subprocess.run(
        [str(args.ffmpeg), "-version"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()[0]

    records: list[dict[str, object]] = []
    failures: list[dict[str, str]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as executor:
        future_to_item = {
            executor.submit(
                materialize_one,
                item,
                args.ffmpeg,
                args.duration_tolerance,
            ): item
            for item in items
        }
        for index, future in enumerate(
            concurrent.futures.as_completed(future_to_item),
            1,
        ):
            item = future_to_item[future]
            try:
                records.append(future.result())
            except Exception as exc:
                failures.append({"utt_id": item.utt_id, "error": repr(exc)})
            if index % 25 == 0 or index == len(items):
                print(f"progress {index}/{len(items)} failures={len(failures)}")

    records.sort(key=lambda record: str(record["target_path"]))
    with (args.audit_dir / "per_utt.tsv").open("w", encoding="utf-8") as handle:
        columns = [
            "utt_id",
            "split",
            "target_path",
            "source_path",
            "source_sha256",
            "target_sha256",
            "expected_duration",
            "duration",
            "sample_rate",
            "channels",
            "subtype",
            "status",
        ]
        handle.write("\t".join(columns) + "\n")
        for record in records:
            handle.write(
                "\t".join(str(record[column]) for column in columns) + "\n"
            )

    counts = {
        "selected": len(items),
        "created": sum(record["status"] == "created" for record in records),
        "resumed": sum(record["status"] == "resumed" for record in records),
        "failed": len(failures),
        "test": sum(record["split"] == "test" for record in records),
        "dev": sum(record["split"] == "dev" for record in records),
        "duration_entries": len(durations),
    }
    config = {
        "build_id": args.build_id,
        "vpc_root": str(args.vpc_root),
        "librispeech_root": str(args.librispeech_root),
        "ffmpeg": str(args.ffmpeg),
        "ffmpeg_version": ffmpeg_version,
        "jobs": args.jobs,
        "duration_tolerance_seconds": args.duration_tolerance,
        "counts": counts,
    }
    (args.audit_dir / "build_config.json").write_text(
        json.dumps(config, indent=2, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )
    (args.audit_dir / "counts.json").write_text(
        json.dumps(counts, indent=2, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )
    (args.audit_dir / "failures.json").write_text(
        json.dumps(failures, indent=2, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )
    (args.audit_dir / "ffmpeg_version.txt").write_text(
        ffmpeg_version + "\n",
        encoding="utf-8",
    )

    if failures:
        print(f"FAILED {len(failures)} utterances", file=sys.stderr)
        return 1
    print(json.dumps(counts, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
