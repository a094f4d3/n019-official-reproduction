"""Build the official LS360 manifest used to train the semi-informed ASV."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Iterator

from n019.manifest import write_json, write_jsonl


def librispeech_fields(relative: Path) -> tuple[str, str]:
    """Return speaker and chapter from a standard LibriSpeech FLAC path."""
    if len(relative.parts) != 3:
        raise ValueError(f"Unexpected LibriSpeech layout: {relative}")
    speaker, chapter, filename = relative.parts
    if not speaker.isdigit() or not chapter.isdigit() or not filename.endswith(".flac"):
        raise ValueError(f"Unexpected LibriSpeech layout: {relative}")
    expected_prefix = f"{speaker}-{chapter}-"
    if not filename.startswith(expected_prefix):
        raise ValueError(
            f"FLAC filename does not match speaker/chapter: {relative}"
        )
    return speaker, chapter


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def vpc_ids(wav_scp: Path) -> list[str]:
    identifiers = []
    with wav_scp.open(encoding="utf-8") as handle:
        for line_number, raw in enumerate(handle, 1):
            fields = raw.strip().split(maxsplit=1)
            if len(fields) != 2:
                raise ValueError(
                    f"Invalid VPC entry at {wav_scp}:{line_number}"
                )
            identifiers.append(fields[0])
    if not identifiers:
        raise ValueError(f"Empty VPC wav.scp: {wav_scp}")
    if len(identifiers) != len(set(identifiers)):
        raise ValueError("VPC train-clean-360 wav.scp contains duplicate IDs")
    return sorted(identifiers)


def inspect_ls360_file(root: Path, path: Path) -> dict:
    import soundfile as sf

    relative = path.relative_to(root)
    speaker, chapter = librispeech_fields(relative)
    identifier = path.stem
    info = sf.info(str(path))
    return {
        "id": identifier,
        "utterance_id": identifier,
        "dataset": "librispeech",
        "split": "train-clean-360",
        "audio": str(path),
        "speaker": speaker,
        "chapter": chapter,
        "gender": None,
        "relative_path": str(relative),
        "bytes": path.stat().st_size,
        "sample_rate": int(info.samplerate),
        "channels": int(info.channels),
        "frames": int(info.frames),
        "seconds": float(info.frames / info.samplerate),
        "sha256": sha256_file(path),
    }


def inspect_ls360_files(
    root: Path,
    audio_paths: list[Path],
    *,
    workers: int,
) -> Iterator[dict]:
    if workers <= 0:
        raise ValueError("workers must be positive")
    if workers == 1:
        for index, path in enumerate(audio_paths, 1):
            yield inspect_ls360_file(root, path)
            if index % 1_000 == 0:
                print(f"inspected={index}/{len(audio_paths)}", flush=True)
        return
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [
            executor.submit(inspect_ls360_file, root, path)
            for path in audio_paths
        ]
        for index, future in enumerate(futures, 1):
            yield future.result()
            if index % 1_000 == 0:
                print(f"inspected={index}/{len(audio_paths)}", flush=True)


def discover_ls360(root: Path, *, workers: int = 8) -> list[dict]:
    root = root.resolve()
    if not root.is_dir():
        raise FileNotFoundError(root)
    audio_paths = sorted(
        path for path in root.rglob("*.flac") if path.is_file()
    )
    if not audio_paths:
        raise ValueError(f"No FLAC files under {root}")
    rows = list(
        inspect_ls360_files(
            root,
            audio_paths,
            workers=workers,
        )
    )
    identifiers = [row["id"] for row in rows]
    if len(identifiers) != len(set(identifiers)):
        raise ValueError("LibriSpeech contains duplicate utterance IDs")
    return rows


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Create an LS360 manifest whose utterance IDs match the official "
            "VPC train-clean-360 Kaldi list."
        )
    )
    parser.add_argument("--train-clean-360", required=True)
    parser.add_argument("--vpc-train-scp", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--workers", type=int, default=8)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    rows = discover_ls360(
        Path(args.train_clean_360),
        workers=args.workers,
    )
    official = vpc_ids(Path(args.vpc_train_scp))
    manifest_ids = [row["id"] for row in rows]
    missing_manifest = sorted(set(official) - set(manifest_ids))
    missing_vpc = sorted(set(manifest_ids) - set(official))
    if missing_manifest or missing_vpc:
        raise ValueError(
            "LibriSpeech/VPC ID mismatch: "
            f"{len(missing_manifest)} VPC-only and "
            f"{len(missing_vpc)} LibriSpeech-only; "
            f"first VPC-only={missing_manifest[:3]}, "
            f"first LibriSpeech-only={missing_vpc[:3]}"
        )
    rows.sort(key=lambda row: row["id"])
    write_jsonl(args.out, rows)
    speakers: dict[str, list[float]] = defaultdict(list)
    for row in rows:
        speakers[row["speaker"]].append(row["seconds"])
    metadata = {
        "dataset": "LibriSpeech train-clean-360",
        "utterances": len(rows),
        "speakers": len(speakers),
        "hours": sum(row["seconds"] for row in rows) / 3600.0,
        "manifest_sha256": sha256_file(Path(args.out)),
        "vpc_train_scp": str(Path(args.vpc_train_scp).resolve()),
        "vpc_train_scp_sha256": sha256_file(Path(args.vpc_train_scp)),
        "sample_rates": sorted({row["sample_rate"] for row in rows}),
        "channels": sorted({row["channels"] for row in rows}),
    }
    write_json(Path(args.out).with_suffix(".meta.json"), metadata)
    print(json.dumps(metadata, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
