#!/usr/bin/env python3
"""Assemble a compact DU-ecapa-nt quality and W-NT summary."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--quality", required=True)
    parser.add_argument("--wnt-summary", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--system", default="DU-ecapa-nt")
    parser.add_argument("--paper-wer", type=float, default=7.59)
    parser.add_argument("--paper-utmos", type=float, default=3.60)
    parser.add_argument("--paper-whisqa", type=float, default=3.70)
    parser.add_argument("--paper-wnt-i", type=float, default=40.3)
    parser.add_argument("--paper-wnt-l", type=float, default=43.0)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    quality_path = Path(args.quality)
    wnt_path = Path(args.wnt_summary)
    quality = json.loads(quality_path.read_text(encoding="utf-8"))
    wnt = json.loads(wnt_path.read_text(encoding="utf-8"))
    result = {
        "system": args.system,
        "quality": quality["values"],
        "paper_quality": {
            "WER": args.paper_wer,
            "UTMOS": args.paper_utmos,
            "WhiSQA": args.paper_whisqa,
        },
        "wnt_I": float(wnt["attacks"]["I"]["mean_eer_percent"]),
        "wnt_L": float(wnt["attacks"]["L"]["mean_eer_percent"]),
        "paper_wnt_I": args.paper_wnt_i,
        "paper_wnt_L": args.paper_wnt_l,
    }
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
