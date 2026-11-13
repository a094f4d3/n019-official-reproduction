"""Collect N019 EER and WER metric files into one JSON summary."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--out", default=None)
    args = parser.parse_args()
    run_dir = Path(args.run_dir)
    output = Path(args.out) if args.out else run_dir / "metrics_summary.json"
    summary = {}
    for path in sorted(run_dir.rglob("*.json")):
        if path == output:
            continue
        metrics = json.loads(path.read_text(encoding="utf-8"))
        metrics.pop("details", None)
        key = path.relative_to(run_dir).with_suffix("").as_posix()
        summary[key] = metrics
    output.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
