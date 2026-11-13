#!/usr/bin/env python3
"""Build a self-contained 100-utterance vocoder selection bundle."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_jsonl(path: Path) -> list[dict]:
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--unit-records", required=True, type=Path)
    parser.add_argument("--speaker-embeddings", required=True, type=Path)
    parser.add_argument("--staging-dir", required=True, type=Path)
    parser.add_argument("--target-root", required=True, type=Path)
    parser.add_argument("--limit", type=int, default=100)
    args = parser.parse_args()

    sources = read_jsonl(args.manifest)[: args.limit]
    if len(sources) != args.limit:
        raise SystemExit(f"Manifest has {len(sources)} rows, need {args.limit}")
    unit_by_id = {str(row["id"]): row for row in read_jsonl(args.unit_records)}
    missing = [str(row["id"]) for row in sources if str(row["id"]) not in unit_by_id]
    if missing:
        raise SystemExit(f"Missing {len(missing)} unit records; first={missing[0]}")

    args.staging_dir.mkdir(parents=True, exist_ok=False)
    audio_dir = args.staging_dir / "audio"
    codes_dir = args.staging_dir / "codes"
    metadata_dir = args.staging_dir / "metadata"
    audio_dir.mkdir()
    codes_dir.mkdir()
    metadata_dir.mkdir()

    output_manifest = []
    output_units = []
    transfer_files: list[dict] = []
    total_bytes = 0

    def copy(source: Path, destination: Path) -> None:
        nonlocal total_bytes
        if not source.is_file():
            raise SystemExit(f"Missing source file: {source}")
        shutil.copy2(source, destination)
        source_sha = sha256(source)
        target_sha = sha256(destination)
        if source_sha != target_sha:
            raise SystemExit(f"Copy hash mismatch: {source} -> {destination}")
        size = destination.stat().st_size
        total_bytes += size
        transfer_files.append(
            {
                "source": str(source.resolve()),
                "staging": str(destination.resolve()),
                "target": str(
                    args.target_root
                    / destination.relative_to(args.staging_dir)
                ),
                "bytes": size,
                "sha256": source_sha,
            }
        )

    codebooks: set[Path] = set()
    for source_row in sources:
        identifier = str(source_row["id"])
        unit = unit_by_id[identifier]
        audio = Path(unit["audio"])
        codes = Path(unit["codes_path"])
        transcript = audio.with_suffix(".normalized.txt")
        if not transcript.is_file():
            raise SystemExit(f"Missing transcript: {transcript}")
        audio_name = audio.name
        code_name = codes.name
        transcript_name = transcript.name

        copy(audio, audio_dir / audio_name)
        copy(codes, codes_dir / code_name)
        copy(transcript, audio_dir / transcript_name)

        local_unit = dict(unit)
        local_unit["audio"] = str(args.target_root / "audio" / audio_name)
        local_unit["codes_path"] = str(args.target_root / "codes" / code_name)
        output_units.append(local_unit)

        local_source = dict(source_row)
        local_source["audio"] = str(args.target_root / "audio" / audio_name)
        output_manifest.append(local_source)
        codebooks.add(Path(unit["kmeans_codebook"]))

    if len(codebooks) != 1:
        raise SystemExit(f"Expected one k-means codebook, found {len(codebooks)}")
    codebook = next(iter(codebooks))
    local_codebook = args.target_root / "metadata" / codebook.name
    copy(codebook, metadata_dir / codebook.name)
    for unit in output_units:
        unit["kmeans_codebook"] = str(local_codebook)

    local_embeddings = args.target_root / "metadata" / args.speaker_embeddings.name
    copy(args.speaker_embeddings, metadata_dir / args.speaker_embeddings.name)

    for name, rows in (
        ("manifest.jsonl", output_manifest),
        ("unit_records.jsonl", output_units),
    ):
        destination = args.staging_dir / name
        destination.write_text(
            "\n".join(json.dumps(row, sort_keys=True) for row in rows) + "\n",
            encoding="utf-8",
        )
        transfer_files.append(
            {
                "staging": str(destination.resolve()),
                "target": str(args.target_root / name),
                "bytes": destination.stat().st_size,
                "sha256": sha256(destination),
            }
        )
        total_bytes += destination.stat().st_size

    summary = {
        "rows": len(sources),
        "speakers": len({str(row["speaker"]) for row in sources}),
        "codebook": str(local_codebook),
        "speaker_embeddings": str(local_embeddings),
        "total_bytes": total_bytes,
        "files": transfer_files,
    }
    summary_path = args.staging_dir / "transfer_manifest.json"
    summary_path.write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({k: v for k, v in summary.items() if k != "files"}, indent=2))
    print(f"TRANSFER_MANIFEST={summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
