"""Join full-evaluation MOS scores with duration and lightweight audio stats."""

from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path

import numpy as np


def read_jsonl(path: Path) -> list[dict]:
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def read_score_table(path: Path) -> list[dict]:
    delimiter = "\t" if path.suffix == ".tsv" else ","
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter=delimiter))


def quantiles(values: list[float]) -> dict[str, float]:
    array = np.asarray(values, dtype=np.float64)
    return {
        "mean": float(array.mean()),
        "stddev": float(array.std(ddof=0)),
        "min": float(array.min()),
        "p05": float(np.quantile(array, 0.05)),
        "p25": float(np.quantile(array, 0.25)),
        "median": float(np.median(array)),
        "p75": float(np.quantile(array, 0.75)),
        "p95": float(np.quantile(array, 0.95)),
        "max": float(array.max()),
    }


def pearson(left: list[float], right: list[float]) -> float | None:
    if len(left) < 3:
        return None
    a = np.asarray(left, dtype=np.float64)
    b = np.asarray(right, dtype=np.float64)
    if np.std(a) == 0.0 or np.std(b) == 0.0:
        return None
    return float(np.corrcoef(a, b)[0, 1])


def audio_stats(path: Path) -> dict[str, float]:
    import soundfile as sf

    audio, sample_rate = sf.read(
        str(path), dtype="float32", always_2d=True
    )
    mono = audio.mean(axis=1, dtype=np.float32)
    frame_size = 1024
    hop = 512
    frame_count = 1 + max(0, (mono.size - frame_size) // hop)
    frames = np.lib.stride_tricks.as_strided(
        mono,
        shape=(frame_count, frame_size),
        strides=(mono.strides[0] * hop, mono.strides[0]),
        writeable=False,
    )
    magnitude = np.abs(np.fft.rfft(frames * np.hanning(frame_size), axis=1))
    magnitude += 1e-12
    power = magnitude**2
    frequencies = np.fft.rfftfreq(frame_size, 1.0 / sample_rate)
    total_power = power.sum(axis=1) + 1e-18
    high_band = (frequencies >= 4000.0) & (frequencies <= 8000.0)
    rms = float(np.sqrt(np.mean(mono.astype(np.float64) ** 2) + 1e-20))
    return {
        "centroid_hz": float(
            np.mean((power * frequencies).sum(axis=1) / total_power)
        ),
        "spectral_flatness": float(
            np.mean(
                np.exp(np.mean(np.log(magnitude), axis=1))
                / np.mean(magnitude, axis=1)
            )
        ),
        "high_band_ratio": float(
            np.mean(power[:, high_band].sum(axis=1) / total_power)
        ),
        "rms_dbfs": 20.0 * math.log10(rms),
        "peak": float(np.max(np.abs(mono))),
        "clipped_fraction": float(np.mean(np.abs(mono) >= 0.999)),
        "silence_fraction": float(np.mean(np.abs(mono) < 1e-4)),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--eval-dir", type=Path, required=True)
    parser.add_argument("--anon-jsonl", type=Path, required=True)
    parser.add_argument("--source-jsonl", type=Path, required=True)
    parser.add_argument("--audio-limit", type=int, default=100)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    utmos_rows = read_score_table(args.eval_dir / "mos" / "UTMOS.tsv")
    whisqa_rows = read_score_table(args.eval_dir / "mos" / "WhiSQA.tsv")
    anon_rows = read_jsonl(args.anon_jsonl)
    source_rows = read_jsonl(args.source_jsonl)
    utmos = {str(row["id"]): float(row["score"]) for row in utmos_rows}
    whisqa = {str(row["id"]): float(row["score"]) for row in whisqa_rows}
    source_seconds = {
        str(row["id"]): float(row["seconds"]) for row in source_rows
    }
    records = []
    for row in anon_rows:
        identifier = str(row["id"])
        if "duration_frames" not in row:
            raise KeyError(
                f"Anonymisation row lacks duration_frames: {identifier}"
            )
        generated_seconds = float(row["duration_frames"]) * 0.02
        source_duration = source_seconds[identifier]
        records.append(
            {
                "id": identifier,
                "speaker": str(row["speaker"]),
                "source_seconds": source_duration,
                "generated_seconds": generated_seconds,
                "duration_ratio": generated_seconds / source_duration,
                "duration_abs_error": abs(generated_seconds - source_duration),
                "UTMOS": utmos[identifier],
                "WhiSQA": whisqa[identifier],
                "audio": str(row["audio"]),
                "source_audio": str(row["source_audio"]),
            }
        )

    if args.audio_limit < 0:
        raise ValueError("--audio-limit must be non-negative")
    audio_records = records[: args.audio_limit]
    for row in audio_records:
        generated = audio_stats(Path(row["audio"]))
        source = audio_stats(Path(row["source_audio"]))
        row["generated_audio"] = generated
        row["source_audio_stats"] = source

    duration_error = [row["duration_abs_error"] for row in records]
    duration_ratio = [row["duration_ratio"] for row in records]
    utmos_values = [row["UTMOS"] for row in records]
    whisqa_values = [row["WhiSQA"] for row in records]
    result = {
        "count": len(records),
        "UTMOS": quantiles(utmos_values),
        "WhiSQA": quantiles(whisqa_values),
        "duration_ratio": quantiles(duration_ratio),
        "duration_abs_error": quantiles(duration_error),
        "correlations": {
            "UTMOS_vs_abs_duration_error": pearson(
                utmos_values, duration_error
            ),
            "WhiSQA_vs_abs_duration_error": pearson(
                whisqa_values, duration_error
            ),
            "UTMOS_vs_duration_ratio": pearson(
                utmos_values, duration_ratio
            ),
            "WhiSQA_vs_duration_ratio": pearson(
                whisqa_values, duration_ratio
            ),
        },
        "lowest_UTMOS": sorted(records, key=lambda row: row["UTMOS"])[:20],
        "highest_UTMOS": sorted(
            records, key=lambda row: row["UTMOS"], reverse=True
        )[:20],
    }
    if audio_records:
        result["audio_subset_count"] = len(audio_records)
        for field in (
            "centroid_hz",
            "spectral_flatness",
            "high_band_ratio",
            "rms_dbfs",
            "peak",
            "clipped_fraction",
            "silence_fraction",
        ):
            result[f"generated_{field}"] = quantiles(
                [row["generated_audio"][field] for row in audio_records]
            )
            result[f"source_{field}"] = quantiles(
                [row["source_audio_stats"][field] for row in audio_records]
            )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
