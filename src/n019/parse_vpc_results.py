"""Parse the official VPC2024 results_orig.txt summary."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path


def read_asv_csv(path: str | Path) -> list[dict]:
    rows = []
    with Path(path).open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            index = row.get("") or row.get("index") or row.get("Unnamed: 0")
            if index is None:
                raise ValueError("ASV CSV is missing its row index column")
            rows.append(
                {
                    "index": int(index),
                    "dataset": row["dataset"],
                    "split": row["split"],
                    "gender": row["gender"],
                    "enrollment": row["enrollment"],
                    "trial": row["trial"],
                    "eer_percent": float(row["EER"]),
                }
            )
    return rows


def parse_vpc_results(
    path: str | Path,
    *,
    results_csv: str | Path | None = None,
) -> dict:
    source = Path(path)
    section = None
    asv_rows = []
    asr_rows = []
    for raw in source.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("---- ASV_eval"):
            section = "asv"
            continue
        if line.startswith("---- ASR results"):
            section = "asr"
            continue
        if line.startswith("----") or line.startswith("dataset "):
            continue
        fields = line.split()
        if section == "asv":
            if len(fields) != 7:
                raise ValueError(f"Invalid ASV row: {line}")
            asv_rows.append(
                {
                    "index": int(fields[0]),
                    "dataset": fields[1],
                    "split": fields[2],
                    "gender": fields[3],
                    "enrollment": fields[4],
                    "trial": fields[5],
                    "eer_percent": float(fields[6]),
                }
            )
        elif section == "asr":
            if len(fields) != 5:
                raise ValueError(f"Invalid ASR row: {line}")
            asr_rows.append(
                {
                    "index": int(fields[0]),
                    "dataset": fields[1],
                    "split": fields[2],
                    "condition": fields[3],
                    "wer_percent": float(fields[4]),
                }
            )
    if not asv_rows and not asr_rows:
        raise ValueError(f"No VPC result rows found in {source}")
    if results_csv is not None:
        by_trial = {
            (
                row["dataset"],
                row["split"],
                row["gender"],
                row["enrollment"],
                row["trial"],
            ): row
            for row in asv_rows
        }
        for row in read_asv_csv(results_csv):
            key = (
                row["dataset"],
                row["split"],
                row["gender"],
                row["enrollment"],
                row["trial"],
            )
            by_trial[key] = row
        asv_rows = sorted(by_trial.values(), key=lambda row: row["index"])

    def selected(enrollment: str, trial: str) -> list[dict]:
        return [
            row
            for row in asv_rows
            if row["dataset"] == "libri"
            and row["split"] == "test"
            and row["enrollment"] == enrollment
            and row["trial"] == trial
        ]

    asv = {}
    for condition, enrollment, trial in (
        ("OO", "original", "original"),
        ("OA", "original", "anon"),
        ("AA", "anon", "anon"),
    ):
        rows = selected(enrollment, trial)
        by_gender = {row["gender"]: row["eer_percent"] for row in rows}
        if set(by_gender) == {"f", "m"}:
            asv[condition] = {
                "female_eer_percent": by_gender["f"],
                "male_eer_percent": by_gender["m"],
                "mean_eer_percent": (by_gender["f"] + by_gender["m"]) / 2.0,
                "rows": rows,
            }
    wer_rows = [
        row
        for row in asr_rows
        if row["dataset"] == "libri" and row["split"] == "test"
    ]
    wer = {
        row["condition"]: row["wer_percent"]
        for row in wer_rows
    }
    timestamp = re.search(
        r"---- Time: (.+?) ----",
        source.read_text(encoding="utf-8"),
    )
    return {
        "source": str(source.resolve()),
        "timestamp": timestamp.group(1).strip() if timestamp else None,
        "asv": asv,
        "wer_percent": wer,
        "asv_rows": asv_rows,
        "asr_rows": asr_rows,
    }


def paper_conditions(asv: dict, model_role: str) -> dict:
    """Map VPC enrollment/trial scenarios to the N019 paper condition names."""
    if model_role == "original":
        mapping = {"OO": "OO", "OA": "I", "AA": "L"}
    elif model_role == "anon":
        mapping = {"AA": "S"}
    else:
        raise ValueError(f"Unsupported VPC model role: {model_role}")
    return {
        paper_label: asv[scenario]
        for scenario, paper_label in mapping.items()
        if scenario in asv
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--results-csv", default=None)
    parser.add_argument("--out", required=True)
    parser.add_argument(
        "--model-role",
        choices=["unspecified", "original", "anon"],
        default="unspecified",
        help=(
            "original maps OA->I and AA->L; anon maps AA->S. "
            "Unspecified keeps only neutral OO/OA/AA labels."
        ),
    )
    args = parser.parse_args()
    payload = parse_vpc_results(
        args.input,
        results_csv=args.results_csv,
    )
    if args.model_role != "unspecified":
        payload["paper_conditions"] = paper_conditions(
            payload["asv"],
            args.model_role,
        )
        payload["model_role"] = args.model_role
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
