"""Report loudness statistics for a random sample of a unit-record corpus."""

from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

import numpy as np
import soundfile as sf


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--records", required=True)
    parser.add_argument("--limit", type=int, default=60)
    parser.add_argument("--seed", type=int, default=20261109)
    args = parser.parse_args()

    rows = []
    with Path(args.records).open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                rows.append(json.loads(line))

    random.Random(args.seed).shuffle(rows)
    rms_values = []
    peak_values = []
    for row in rows[: args.limit]:
        audio, _ = sf.read(str(row["audio"]), dtype="float32", always_2d=True)
        mono = audio.mean(axis=1)
        rms = float(np.sqrt(np.mean(np.square(mono, dtype=np.float64)) + 1e-20))
        peak = float(np.max(np.abs(mono)) + 1e-20)
        rms_values.append(20.0 * math.log10(rms))
        peak_values.append(20.0 * math.log10(peak))

    print(
        json.dumps(
            {
                "n": len(rms_values),
                "rms_dbfs_mean": float(np.mean(rms_values)),
                "rms_dbfs_median": float(np.median(rms_values)),
                "peak_dbfs_mean": float(np.mean(peak_values)),
                "peak_dbfs_median": float(np.median(peak_values)),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
