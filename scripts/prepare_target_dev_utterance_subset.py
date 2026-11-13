"""Copy the dev target utterances into a self-contained local subset."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-map", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--expected", type=int, default=100)
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    args = parse_args()
    target_map = Path(args.target_map)
    rows = [
        json.loads(line)
        for line in target_map.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if len(rows) != args.expected:
        raise SystemExit(
            f"Expected {args.expected} target-map rows, got {len(rows)}"
        )

    output = Path(args.out)
    audio_dir = output / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    manifest = []
    seen_ids: set[str] = set()
    seen_names: set[str] = set()
    duplicate_mappings = 0
    for row in rows:
        identifier = str(row["target_id"])
        speaker = str(row["target_speaker"])
        source = Path(row["target_audio"])
        if identifier in seen_ids:
            duplicate_mappings += 1
            continue
        if not source.is_file():
            raise SystemExit(f"Missing target audio: {source}")
        name = source.name
        if name in seen_names:
            raise SystemExit(f"Duplicate target basename: {name}")
        seen_ids.add(identifier)
        seen_names.add(name)

        destination = audio_dir / name
        if (
            not destination.is_file()
            or destination.stat().st_size != source.stat().st_size
        ):
            shutil.copy2(source, destination)
        source_sha = sha256_file(source)
        destination_sha = sha256_file(destination)
        if source_sha != destination_sha:
            raise SystemExit(f"SHA256 mismatch: {source} -> {destination}")
        manifest.append(
            {
                "id": identifier,
                "speaker": speaker,
                "audio": str(destination.resolve()),
                "source_audio": str(source),
                "bytes": destination.stat().st_size,
                "sha256": destination_sha,
                "dataset": "libritts",
                "split": "train-other-500",
            }
        )

    manifest_path = output / "target_utterance_manifest.jsonl"
    manifest_path.write_text(
        "".join(
            json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n"
            for row in manifest
        ),
        encoding="utf-8",
    )
    summary = {
        "target_map": str(target_map.resolve()),
        "target_map_sha256": sha256_file(target_map),
        "mapping_rows": len(rows),
        "duplicate_mapping_rows": duplicate_mappings,
        "unique_target_utterances": len(manifest),
        "speakers": len({row["speaker"] for row in manifest}),
        "manifest": str(manifest_path.resolve()),
        "manifest_sha256": sha256_file(manifest_path),
    }
    (output / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
