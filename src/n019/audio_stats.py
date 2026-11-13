"""Summarize source and generated durations for an anonymized manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import soundfile as sf


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    rows = [
        json.loads(line)
        for line in Path(args.manifest).read_text(encoding="utf-8").splitlines()
    ]
    source_seconds = np.array([float(row["seconds"]) for row in rows])
    generated_seconds = np.array(
        [sf.info(row["audio"]).duration for row in rows]
    )
    ratios = generated_seconds / source_seconds
    result = {
        "utterances": len(rows),
        "source_seconds": float(source_seconds.sum()),
        "generated_seconds": float(generated_seconds.sum()),
        "duration_ratio": float(generated_seconds.sum() / source_seconds.sum()),
        "per_utterance_ratio_mean": float(ratios.mean()),
        "per_utterance_ratio_median": float(np.median(ratios)),
        "per_utterance_ratio_min": float(ratios.min()),
        "per_utterance_ratio_max": float(ratios.max()),
    }
    output = Path(args.out)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
