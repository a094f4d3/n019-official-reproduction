from __future__ import annotations

import unittest

from n019.compare_paper import compare_system, render_markdown


PAPER = {
    "paper": {"doi": "example", "table": 1},
    "default_tolerances": {
        "E-VPC I": 0.5,
        "WER": 0.5,
        "UTMOS": 0.05,
    },
    "tolerance_note": "reporting choice",
    "systems": {
        "DU-pred-nt": {
            "E-VPC I": 47.2,
            "WER": 7.41,
            "UTMOS": 3.63,
        },
        "Original": {
            "E-VPC I": None,
            "WER": 1.8,
        },
    },
}


class ComparePaperTests(unittest.TestCase):
    def test_computes_absolute_relative_and_tolerance_status(self) -> None:
        result = compare_system(
            system="DU-pred-nt",
            reproduced={"E-VPC I": 46.87, "WER": 8.1, "UTMOS": 3.61},
            paper_table=PAPER,
        )
        self.assertEqual(
            result["metrics"]["E-VPC I"]["status"],
            "within_tolerance",
        )
        self.assertAlmostEqual(
            result["metrics"]["E-VPC I"]["absolute_difference"],
            -0.33,
        )
        self.assertAlmostEqual(
            result["metrics"]["E-VPC I"]["relative_difference_percent"],
            -0.6991525423728812,
        )
        self.assertEqual(
            result["metrics"]["WER"]["status"],
            "outside_tolerance",
        )
        self.assertEqual(result["completed_metrics"], 3)
        self.assertTrue(result["all_reported_metrics_complete"])

    def test_missing_reproduction_is_pending_not_imputed(self) -> None:
        result = compare_system(
            system="DU-pred-nt",
            reproduced={"E-VPC I": 47.0},
            paper_table=PAPER,
        )
        self.assertEqual(result["metrics"]["WER"]["status"], "pending")
        self.assertIsNone(result["metrics"]["WER"]["reproduced"])
        self.assertEqual(result["pending"], 2)
        self.assertFalse(result["all_reported_metrics_complete"])

    def test_null_paper_cell_is_not_treated_as_pending(self) -> None:
        result = compare_system(
            system="Original",
            reproduced={"E-VPC I": 4.6, "WER": 1.8},
            paper_table=PAPER,
        )
        self.assertEqual(
            result["metrics"]["E-VPC I"]["status"],
            "not_reported_by_paper",
        )
        self.assertTrue(result["all_reported_metrics_complete"])

    def test_markdown_never_hides_missing_values(self) -> None:
        result = compare_system(
            system="DU-pred-nt",
            reproduced={"E-VPC I": 47.2},
            paper_table=PAPER,
        )
        markdown = render_markdown(result)
        self.assertIn("| WER | 7.4100 | - |", markdown)
        self.assertIn("`pending`", markdown)

    def test_unknown_system_is_rejected(self) -> None:
        with self.assertRaisesRegex(KeyError, "Unknown"):
            compare_system(
                system="not-a-system",
                reproduced={},
                paper_table=PAPER,
            )


if __name__ == "__main__":
    unittest.main()
