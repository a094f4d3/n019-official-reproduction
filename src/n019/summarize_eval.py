"""Render the core N019 EER/WER comparison as JSON and Markdown."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


PAPER = {
    "DU-orig-nt": {
        "W-NT I": 33.1,
        "W-NT L": 33.6,
        "WER": 4.48,
    },
    "DU-pred-nt": {
        "W-NT I": 39.9,
        "W-NT L": 42.3,
        "WER": 7.41,
    },
}


def read_metric(run_dir: Path, name: str) -> dict:
    return json.loads((run_dir / name).read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--out", default=None)
    args = parser.parse_args()
    run_dir = Path(args.run_dir)
    systems = {}
    for mode, label in [("orig", "DU-orig-nt"), ("pred", "DU-pred-nt")]:
        systems[label] = {
            "E-VPC I": 100 * read_metric(run_dir, f"ecapa_{mode}_I.json")["eer"],
            "E-VPC L": 100 * read_metric(run_dir, f"ecapa_{mode}_L.json")["eer"],
            "W-NT I": 100 * read_metric(run_dir, f"wpro_{mode}_I.json")["eer"],
            "W-NT L": 100 * read_metric(run_dir, f"wpro_{mode}_L.json")["eer"],
            "WER": 100 * read_metric(run_dir, f"wer_{mode}.json")["wer"],
            "duration_ratio": read_metric(
                run_dir, f"duration_stats_{mode}.json"
            )["duration_ratio"],
            "closer_to_target_fraction": read_metric(
                run_dir, f"speaker_diagnostics_{mode}.json"
            )["closer_to_target_fraction"],
        }
    payload = {"local": systems, "paper": PAPER}
    output = Path(args.out) if args.out else run_dir / "core_comparison.json"
    output.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    lines = [
        "| System | E-VPC I | E-VPC L | W-NT I | W-NT L | WER | Duration ratio | Closer to target |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for label, values in systems.items():
        lines.append(
            f"| {label} | {values['E-VPC I']:.2f} | {values['E-VPC L']:.2f} | "
            f"{values['W-NT I']:.2f} | {values['W-NT L']:.2f} | "
            f"{values['WER']:.2f} | {values['duration_ratio']:.4f} | "
            f"{100 * values['closer_to_target_fraction']:.1f}% |"
        )
    markdown = "\n".join(lines) + "\n"
    (run_dir / "core_comparison.md").write_text(markdown, encoding="utf-8")
    print(markdown, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
