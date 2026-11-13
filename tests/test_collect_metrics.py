from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

from n019 import collect_metrics


class CollectMetricsTests(unittest.TestCase):
    def test_collects_nested_json_with_relative_keys(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            nested = root / "eval" / "wnt"
            nested.mkdir(parents=True)
            (nested / "summary.json").write_text(
                json.dumps({"attacks": {"I": {"mean_eer_percent": 42.0}}}),
                encoding="utf-8",
            )
            output = root / "metrics_summary.json"
            argv = sys.argv
            try:
                sys.argv = [
                    "collect_metrics",
                    "--run-dir",
                    str(root),
                    "--out",
                    str(output),
                ]
                self.assertEqual(collect_metrics.main(), 0)
            finally:
                sys.argv = argv
            summary = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(
                summary["eval/wnt/summary"]["attacks"]["I"][
                    "mean_eer_percent"
                ],
                42.0,
            )


if __name__ == "__main__":
    unittest.main()
