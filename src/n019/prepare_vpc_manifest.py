"""Build a de-duplicated manifest from official VPC2024 Kaldi lists."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from n019.manifest import write_json, write_jsonl


def read_kv(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    if not path.is_file():
        return result
    with path.open("r", encoding="utf-8") as handle:
        for line_number, raw_line in enumerate(handle, 1):
            line = raw_line.strip()
            if not line:
                continue
            fields = line.split(maxsplit=1)
            if len(fields) != 2:
                raise ValueError(f"Invalid line {path}:{line_number}")
            result[fields[0]] = fields[1]
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--vpc-root",
        required=True,
        help="Directory containing VPC data/, for example .../models/vpc.",
    )
    parser.add_argument("--out", required=True)
    parser.add_argument(
        "--subset",
        choices=["libri_test", "libri_dev", "all"],
        default="libri_test",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.vpc_root).resolve()
    data_root = root / "data"
    if not data_root.is_dir():
        raise FileNotFoundError(data_root)
    rows: dict[str, dict] = {}
    for manifest_dir in sorted(data_root.glob("libri_*_*")):
        if not manifest_dir.is_dir():
            continue
        if args.subset != "all" and not manifest_dir.name.startswith(args.subset):
            continue
        wav_scp = read_kv(manifest_dir / "wav.scp")
        utt2spk = read_kv(manifest_dir / "utt2spk")
        texts = read_kv(manifest_dir / "text")
        durations = read_kv(manifest_dir / "utt2dur")
        speakers = read_kv(manifest_dir / "spk2gender")
        for identifier, relative_audio in wav_scp.items():
            if identifier not in utt2spk:
                raise KeyError(f"{identifier} missing utt2spk")
            speaker = utt2spk[identifier]
            audio = (root / relative_audio).resolve()
            if not audio.is_file():
                raise FileNotFoundError(audio)
            row = {
                "id": identifier,
                "utterance_id": identifier,
                "speaker": speaker,
                "gender": speakers.get(speaker),
                "audio": str(audio),
                "text": texts.get(identifier, ""),
                "seconds": float(durations[identifier])
                if identifier in durations
                else None,
                "subsets": [manifest_dir.name],
                "source_relative_audio": relative_audio,
            }
            previous = rows.get(identifier)
            if previous is None:
                rows[identifier] = row
            else:
                if previous["audio"] != row["audio"] or previous["speaker"] != row["speaker"]:
                    raise ValueError(f"Inconsistent rows for {identifier}")
                previous["subsets"] = sorted(
                    set(previous["subsets"] + row["subsets"])
                )
    if not rows:
        raise RuntimeError("No VPC manifest rows selected")
    ordered = [rows[key] for key in sorted(rows)]
    write_jsonl(args.out, ordered)
    write_json(
        f"{args.out}.meta.json",
        {
            "vpc_root": str(root),
            "subset": args.subset,
            "utterances": len(ordered),
            "speakers": len({row["speaker"] for row in ordered}),
        },
    )
    print(json.dumps({"rows": len(ordered)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
