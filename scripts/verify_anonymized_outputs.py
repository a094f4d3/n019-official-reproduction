#!/usr/bin/env python3
"""Verify one completed LS360 anonymisation output and its VPC export."""

from __future__ import annotations

import argparse
import hashlib
import json
import pwd
import wave
from pathlib import Path


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(16 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_jsonl(path: Path) -> list[dict]:
    with path.open("r", encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def wav_info(path: Path) -> dict[str, int]:
    with wave.open(str(path), "rb") as handle:
        return {
            "channels": handle.getnchannels(),
            "sample_rate": handle.getframerate(),
            "sample_width": handle.getsampwidth(),
            "frames": handle.getnframes(),
        }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-manifest", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--vpc-suffix-dir", type=Path, required=True)
    parser.add_argument("--duration-mode", choices=["orig", "pred", "nt", "ecapa"])
    parser.add_argument("--vocoder-type", choices=["nt", "ecapa"])
    parser.add_argument("--expected-records", type=int, default=104014)
    parser.add_argument("--expected-owner")
    parser.add_argument("--expected-uid", type=int)
    parser.add_argument("--expected-gid", type=int)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    source_path = args.source_manifest.resolve()
    out_dir = args.out_dir.resolve()
    vpc_dir = args.vpc_suffix_dir.resolve()
    anon_path = out_dir / "anon.jsonl"
    meta_path = out_dir / "run_meta.json"
    vpc_scp = vpc_dir / "wav.scp"
    for path in (source_path, anon_path, meta_path, vpc_scp):
        if not path.is_file():
            raise FileNotFoundError(path)

    sources = read_jsonl(source_path)
    rows = read_jsonl(anon_path)
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    source_ids = [str(row["id"]) for row in sources]
    output_ids = [str(row["id"]) for row in rows]
    output_audio = [Path(str(row["audio"])).resolve() for row in rows]
    wav_files = sorted(out_dir.glob("*.wav"))
    wav_set = {path.resolve() for path in wav_files}

    vpc_ids: list[str] = []
    vpc_audio: list[Path] = []
    for line in vpc_scp.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        identifier, audio = line.split(maxsplit=1)
        vpc_ids.append(identifier)
        vpc_audio.append(Path(audio).resolve())

    sample_indices = sorted({0, len(rows) // 2, len(rows) - 1})
    sample_wavs = [
        {"path": str(output_audio[index]), **wav_info(output_audio[index])}
        for index in sample_indices
    ]
    negative_duration_values = sum(
        int(row.get("negative_duration_values", 0)) for row in rows
    )
    mode_mismatches = (
        sum(row.get("duration_mode") != args.duration_mode for row in rows)
        if args.duration_mode
        else 0
    )
    type_mismatches = (
        sum(row.get("vocoder_type") != args.vocoder_type for row in rows)
        if args.vocoder_type
        else 0
    )
    output_stat = out_dir.stat()
    try:
        owner = pwd.getpwuid(output_stat.st_uid).pw_name
    except KeyError:
        owner = str(output_stat.st_uid)
    checks = {
        "source_rows": len(sources) == args.expected_records,
        "anon_rows": len(rows) == args.expected_records,
        "output_ids_unique": len(set(output_ids)) == len(output_ids),
        "output_ids_match_source": set(output_ids) == set(source_ids),
        "wav_count": len(wav_files) == args.expected_records,
        "row_audio_matches_wav_set": set(output_audio) == wav_set,
        "row_audio_files_exist": all(path.is_file() for path in output_audio),
        "vpc_rows": len(vpc_ids) == args.expected_records,
        "vpc_ids_unique": len(set(vpc_ids)) == len(vpc_ids),
        "vpc_ids_match_source": set(vpc_ids) == set(source_ids),
        "vpc_audio_matches_rows": set(vpc_audio) == set(output_audio),
        "run_meta_records": int(meta.get("records", -1)) == args.expected_records,
        "negative_duration_total_matches": int(
            meta.get("negative_duration_values", -1)
        )
        == negative_duration_values,
        "duration_mode": mode_mismatches == 0,
        "vocoder_type": type_mismatches == 0,
        "sample_wavs_valid": all(
            item["channels"] == 1
            and item["sample_rate"] == 16000
            and item["sample_width"] == 2
            and item["frames"] > 0
            for item in sample_wavs
        ),
        "owner_matches": args.expected_owner is None
        or owner == args.expected_owner,
        "owner_uid_matches": args.expected_uid is None
        or output_stat.st_uid == args.expected_uid,
        "owner_gid_matches": args.expected_gid is None
        or output_stat.st_gid == args.expected_gid,
    }
    report = {
        "source_manifest": str(source_path),
        "source_manifest_sha256": sha256_file(source_path),
        "out_dir": str(out_dir),
        "anon_jsonl_sha256": sha256_file(anon_path),
        "run_meta_sha256": sha256_file(meta_path),
        "vpc_wav_scp": str(vpc_scp),
        "vpc_wav_scp_sha256": sha256_file(vpc_scp),
        "source_rows": len(sources),
        "anon_rows": len(rows),
        "wav_files": len(wav_files),
        "wav_bytes": sum(path.stat().st_size for path in wav_files),
        "vpc_rows": len(vpc_ids),
        "duration_mode": meta.get("args", {}).get("duration_mode"),
        "vocoder_type": meta.get("args", {}).get("vocoder_type"),
        "vocoder_version": meta.get("vocoder_version"),
        "elapsed_seconds": meta.get("elapsed_seconds"),
        "negative_duration_values": negative_duration_values,
        "owner": owner,
        "owner_uid": output_stat.st_uid,
        "owner_gid": output_stat.st_gid,
        "sample_wavs": sample_wavs,
        "checks": checks,
        "passed": all(checks.values()),
    }
    encoded = json.dumps(report, indent=2, sort_keys=True)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
