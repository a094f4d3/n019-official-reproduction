"""Rank vocoder checkpoints by paired MOS quality with a WER safety gate."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from n019.manifest import write_json


METRIC_KEYS = ("utmos_mean", "whisqa_mean", "wer_percent")


def load_candidate(path: str | Path) -> dict:
    value = json.loads(Path(path).read_text(encoding="utf-8"))
    required = {"id", "checkpoint", "count", *METRIC_KEYS}
    missing = sorted(required - set(value))
    if missing:
        raise ValueError(f"{path} is missing fields: {missing}")
    for key in METRIC_KEYS:
        metric = float(value[key])
        if not math.isfinite(metric):
            raise ValueError(f"Non-finite {key} in {path}")
        value[key] = metric
    value["count"] = int(value["count"])
    if value["count"] <= 0:
        raise ValueError(f"Invalid count in {path}")
    value["source_json"] = str(Path(path).resolve())
    return value


def rank_candidates(
    candidates: list[dict],
    *,
    baseline_id: str,
    min_utmos_gain: float,
    min_whisqa_gain: float,
    max_wer_regression: float,
) -> dict:
    if not candidates:
        raise ValueError("No candidates")
    if min_utmos_gain < 0.0 or min_whisqa_gain < 0.0:
        raise ValueError("Minimum MOS gains must be non-negative")
    if max_wer_regression < 0.0:
        raise ValueError("WER regression tolerance must be non-negative")
    by_id = {candidate["id"]: candidate for candidate in candidates}
    if len(by_id) != len(candidates):
        raise ValueError("Candidate IDs are not unique")
    baseline = by_id.get(baseline_id)
    if baseline is None:
        raise KeyError(f"Baseline candidate not found: {baseline_id}")
    counts = {candidate["count"] for candidate in candidates}
    if len(counts) != 1:
        raise ValueError(f"Candidate evaluation counts differ: {sorted(counts)}")

    rows = []
    for candidate in candidates:
        delta_utmos = candidate["utmos_mean"] - baseline["utmos_mean"]
        delta_whisqa = candidate["whisqa_mean"] - baseline["whisqa_mean"]
        delta_wer = candidate["wer_percent"] - baseline["wer_percent"]
        eligible = (
            delta_utmos >= min_utmos_gain
            and delta_whisqa >= min_whisqa_gain
            and delta_wer <= max_wer_regression
        )
        rows.append(
            {
                **candidate,
                "delta_utmos": delta_utmos,
                "delta_whisqa": delta_whisqa,
                "delta_wer_percent": delta_wer,
                "mos_rank_score": (delta_utmos + delta_whisqa) / 2.0,
                "eligible": eligible,
            }
        )
    ranked = sorted(
        rows,
        key=lambda row: (
            row["eligible"],
            row["mos_rank_score"],
            -row["delta_wer_percent"],
        ),
        reverse=True,
    )
    eligible = [row for row in ranked if row["eligible"]]
    selected = eligible[0] if eligible else baseline
    return {
        "baseline_id": baseline_id,
        "selection_policy": "paired_mos_with_wer_gate",
        "thresholds": {
            "min_utmos_gain": min_utmos_gain,
            "min_whisqa_gain": min_whisqa_gain,
            "max_wer_regression_percent": max_wer_regression,
        },
        "selected_id": selected["id"],
        "selected_checkpoint": selected["checkpoint"],
        "selected_checkpoint_sha256": selected.get("checkpoint_sha256"),
        "selected_metrics": {
            "utmos_mean": selected["utmos_mean"],
            "whisqa_mean": selected["whisqa_mean"],
            "wer_percent": selected["wer_percent"],
        },
        "candidates": ranked,
    }


def markdown_report(result: dict) -> str:
    lines = [
        "# N019 Vocoder Snapshot Selection",
        "",
        f"- Baseline: `{result['baseline_id']}`",
        f"- Selected: `{result['selected_id']}`",
        "- Policy: paired UTMOS/WhiSQA gain with a WER safety gate",
        "",
        "| Candidate | UTMOS | dUTMOS | WhiSQA | dWhiSQA | WER % | dWER | Eligible |",
        "|---|---:|---:|---:|---:|---:|---:|:---:|",
    ]
    for row in result["candidates"]:
        lines.append(
            "| {id} | {utmos:.6f} | {du:+.6f} | {whisqa:.6f} | "
            "{dw:+.6f} | {wer:.6f} | {dwer:+.6f} | {eligible} |".format(
                id=row["id"],
                utmos=row["utmos_mean"],
                du=row["delta_utmos"],
                whisqa=row["whisqa_mean"],
                dw=row["delta_whisqa"],
                wer=row["wer_percent"],
                dwer=row["delta_wer_percent"],
                eligible="yes" if row["eligible"] else "no",
            )
        )
    return "\n".join(lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", action="append", required=True)
    parser.add_argument("--baseline-id", required=True)
    parser.add_argument("--min-utmos-gain", type=float, default=0.05)
    parser.add_argument("--min-whisqa-gain", type=float, default=0.05)
    parser.add_argument("--max-wer-regression", type=float, default=0.25)
    parser.add_argument("--out", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = rank_candidates(
        [load_candidate(path) for path in args.candidate],
        baseline_id=args.baseline_id,
        min_utmos_gain=args.min_utmos_gain,
        min_whisqa_gain=args.min_whisqa_gain,
        max_wer_regression=args.max_wer_regression,
    )
    out = Path(args.out)
    write_json(out, result)
    out.with_suffix(".md").write_text(markdown_report(result), encoding="utf-8")
    print(markdown_report(result), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
