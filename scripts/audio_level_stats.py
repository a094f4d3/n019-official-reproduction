"""Compare loudness/peak statistics between source and anonymised audio."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
import soundfile as sf


def read_mono(path: Path) -> tuple[np.ndarray, int]:
    audio, sample_rate = sf.read(str(path), dtype="float32", always_2d=True)
    mono = audio.mean(axis=1)
    return mono, sample_rate


def stats(mono: np.ndarray, sample_rate: int) -> dict[str, float]:
    rms = float(np.sqrt(np.mean(np.square(mono, dtype=np.float64)) + 1e-20))
    peak = float(np.max(np.abs(mono)) + 1e-20)
    return {
        "seconds": len(mono) / sample_rate,
        "rms_dbfs": 20.0 * math.log10(rms),
        "peak_dbfs": 20.0 * math.log10(peak),
        "clip_ratio": float(np.mean(np.abs(mono) > 0.999)),
        "dc": float(np.mean(mono)),
    }


def summarize(values: list[float]) -> dict[str, float]:
    array = np.asarray(values, dtype=np.float64)
    return {
        "mean": float(array.mean()),
        "median": float(np.median(array)),
        "p10": float(np.percentile(array, 10)),
        "p90": float(np.percentile(array, 90)),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--anon-jsonl", required=True)
    parser.add_argument("--limit", type=int, default=100)
    args = parser.parse_args()

    rows = []
    with Path(args.anon_jsonl).open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                rows.append(json.loads(line))
            if len(rows) >= args.limit:
                break

    source_stats = []
    anon_stats = []
    for row in rows:
        src, src_sr = read_mono(Path(row["source_audio"]))
        out, out_sr = read_mono(Path(row["audio"]))
        source_stats.append(stats(src, src_sr))
        anon_stats.append(stats(out, out_sr))

    report = {
        "n": len(rows),
        "source": {
            key: summarize([item[key] for item in source_stats])
            for key in ("seconds", "rms_dbfs", "peak_dbfs", "clip_ratio", "dc")
        },
        "anon": {
            key: summarize([item[key] for item in anon_stats])
            for key in ("seconds", "rms_dbfs", "peak_dbfs", "clip_ratio", "dc")
        },
    }
    report["delta_rms_db"] = (
        report["anon"]["rms_dbfs"]["mean"] - report["source"]["rms_dbfs"]["mean"]
    )
    report["delta_peak_db"] = (
        report["anon"]["peak_dbfs"]["mean"] - report["source"]["peak_dbfs"]["mean"]
    )
    report["duration_ratio"] = (
        report["anon"]["seconds"]["mean"] / report["source"]["seconds"]["mean"]
    )
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
