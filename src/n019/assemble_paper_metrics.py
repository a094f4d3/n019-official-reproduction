"""Assemble measured N019 metrics into the paper-comparison input schema."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ALLOWED_METRICS = {
    "E-VPC I",
    "E-VPC L",
    "E-VPC S",
    "W-NT I",
    "W-NT L",
    "W-NT S",
    "WER",
    "UTMOS",
    "WhiSQA",
}


def load_optional_json(path: str | None) -> dict | None:
    if path is None:
        return None
    return json.loads(Path(path).read_text(encoding="utf-8"))


def extract_evpc(data: dict | None, label: str) -> float | None:
    if data is None:
        return None
    condition = data.get("paper_conditions", {}).get(label)
    if condition is None:
        return None
    return float(condition["mean_eer_percent"])


def extract_wnt(data: dict | None, attack: str) -> float | None:
    if data is None:
        return None
    condition = data.get("attacks", {}).get(attack)
    if condition is None:
        return None
    return float(condition["mean_eer_percent"])


def extract_wer(
    data: dict | None,
    *,
    condition: str,
) -> float | None:
    if data is None:
        return None
    values = data.get("wer_percent", {})
    if isinstance(values, (int, float)):
        return float(values)
    if condition not in values:
        return None
    return float(values[condition])


def extract_mos(data: dict | None) -> float | None:
    if data is None:
        return None
    if "mean" not in data:
        raise KeyError("MOS JSON is missing mean")
    return float(data["mean"])


def assemble(args: argparse.Namespace) -> dict:
    evpc = load_optional_json(args.evpc)
    s_eval = load_optional_json(args.s_eval)
    wnt = load_optional_json(args.wnt_summary)
    wer_source = load_optional_json(args.wer_json)
    utmos = load_optional_json(args.utmos)
    whisqa = load_optional_json(args.whisqa)
    values = {
        "E-VPC I": extract_evpc(evpc, "I"),
        "E-VPC L": extract_evpc(evpc, "L"),
        "E-VPC S": extract_evpc(s_eval, "S"),
        "W-NT I": extract_wnt(wnt, "I"),
        "W-NT L": extract_wnt(wnt, "L"),
        "W-NT S": extract_wnt(wnt, "S"),
        "WER": extract_wer(wer_source, condition=args.wer_condition),
        "UTMOS": extract_mos(utmos),
        "WhiSQA": extract_mos(whisqa),
    }
    if set(values) != ALLOWED_METRICS:
        raise RuntimeError("Internal metric schema mismatch")
    return {
        "system": args.system,
        "values": {
            key: value
            for key, value in values.items()
            if value is not None
        },
        "missing": sorted(
            key for key, value in values.items() if value is None
        ),
        "sources": {
            "evpc": args.evpc,
            "s_eval": args.s_eval,
            "wnt_summary": args.wnt_summary,
            "wer_json": args.wer_json,
            "wer_condition": args.wer_condition,
            "utmos": args.utmos,
            "whisqa": args.whisqa,
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Assemble measured metrics for n019.compare_paper."
    )
    parser.add_argument("--system", required=True)
    parser.add_argument("--evpc", default=None)
    parser.add_argument("--s-eval", default=None)
    parser.add_argument("--wnt-summary", default=None)
    parser.add_argument("--wer-json", default=None)
    parser.add_argument(
        "--wer-condition",
        choices=["original", "anon"],
        default="anon",
    )
    parser.add_argument("--utmos", default=None)
    parser.add_argument("--whisqa", default=None)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    if not any(
        (
            args.evpc,
            args.s_eval,
            args.wnt_summary,
            args.wer_json,
            args.utmos,
            args.whisqa,
        )
    ):
        parser.error("At least one metric source is required")
    return args


def main() -> int:
    args = parse_args()
    result = assemble(args)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
