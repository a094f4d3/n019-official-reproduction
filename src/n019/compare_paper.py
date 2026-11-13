"""Compare reproduced N019 metrics against the published Table 1."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path


def load_json(path: str | Path) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def compare_system(
    *,
    system: str,
    reproduced: dict,
    paper_table: dict,
) -> dict:
    systems = paper_table.get("systems", {})
    if system not in systems:
        raise KeyError(f"Unknown paper Table 1 system: {system}")
    paper = systems[system]
    tolerances = paper_table.get("default_tolerances", {})
    rows = {}
    for metric, paper_value in paper.items():
        tolerance = float(tolerances.get(metric, 0.0))
        if tolerance < 0.0:
            raise ValueError(f"Negative tolerance for {metric}")
        value = reproduced.get(metric)
        if paper_value is None:
            rows[metric] = {
                "paper": None,
                "reproduced": value,
                "absolute_difference": None,
                "relative_difference_percent": None,
                "tolerance": tolerance,
                "status": "not_reported_by_paper",
            }
            continue
        if value is None:
            rows[metric] = {
                "paper": float(paper_value),
                "reproduced": None,
                "absolute_difference": None,
                "relative_difference_percent": None,
                "tolerance": tolerance,
                "status": "pending",
            }
            continue
        reproduced_value = float(value)
        if not math.isfinite(reproduced_value):
            raise ValueError(f"Non-finite reproduced value for {system}/{metric}")
        absolute = reproduced_value - float(paper_value)
        rows[metric] = {
            "paper": float(paper_value),
            "reproduced": reproduced_value,
            "absolute_difference": absolute,
            "relative_difference_percent": (
                100.0 * absolute / float(paper_value)
                if float(paper_value) != 0.0
                else None
            ),
            "tolerance": tolerance,
            "status": "within_tolerance" if abs(absolute) <= tolerance else "outside_tolerance",
        }
    statuses = [row["status"] for row in rows.values()]
    return {
        "system": system,
        "paper_doi": paper_table.get("paper", {}).get("doi"),
        "table": paper_table.get("paper", {}).get("table"),
        "tolerance_note": paper_table.get("tolerance_note"),
        "metrics": rows,
        "completed_metrics": sum(
            status in {"within_tolerance", "outside_tolerance"}
            for status in statuses
        ),
        "within_tolerance": statuses.count("within_tolerance"),
        "outside_tolerance": statuses.count("outside_tolerance"),
        "pending": statuses.count("pending"),
        "all_reported_metrics_complete": not any(
            status == "pending" for status in statuses
        ),
    }


def render_markdown(result: dict) -> str:
    lines = [
        f"# {result['system']} vs paper Table {result['table']}",
        "",
        f"DOI: `{result['paper_doi']}`",
        "",
        "| Metric | Paper | Reproduced | Abs. diff | Rel. diff | Tolerance | Status |",
        "|---|---:|---:|---:|---:|---:|---|",
    ]
    for metric, row in result["metrics"].items():
        def number(value):
            return "-" if value is None else f"{value:.4f}"

        relative = (
            "-"
            if row["relative_difference_percent"] is None
            else f"{row['relative_difference_percent']:+.2f}%"
        )
        lines.append(
            f"| {metric} | {number(row['paper'])} | "
            f"{number(row['reproduced'])} | "
            f"{number(row['absolute_difference'])} | {relative} | "
            f"{row['tolerance']:.4f} | `{row['status']}` |"
        )
    lines.extend(
        [
            "",
            (
                f"Completed: {result['completed_metrics']}; "
                f"within tolerance: {result['within_tolerance']}; "
                f"outside: {result['outside_tolerance']}; "
                f"pending: {result['pending']}."
            ),
            "",
            f"Tolerance note: {result['tolerance_note']}",
            "",
        ]
    )
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compare one reproduced DU system with paper Table 1."
    )
    parser.add_argument("--paper-table", required=True)
    parser.add_argument("--system", required=True)
    parser.add_argument(
        "--metrics",
        required=True,
        help=(
            "JSON with keys system and values, where values maps metric names "
            "such as 'E-VPC I' and 'WER' to numbers."
        ),
    )
    parser.add_argument("--out-json", required=True)
    parser.add_argument("--out-md", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    paper_table = load_json(args.paper_table)
    payload = load_json(args.metrics)
    if payload.get("system") != args.system:
        raise ValueError(
            f"Metrics system {payload.get('system')!r} does not match "
            f"--system {args.system!r}"
        )
    values = payload.get("values")
    if not isinstance(values, dict):
        raise ValueError("Metrics JSON must contain an object named values")
    result = compare_system(
        system=args.system,
        reproduced=values,
        paper_table=paper_table,
    )
    out_json = Path(args.out_json)
    out_md = Path(args.out_md)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    out_md.write_text(render_markdown(result), encoding="utf-8")
    print(render_markdown(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
