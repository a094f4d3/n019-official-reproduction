from __future__ import annotations

import unittest

from n019.rank_vocoder_snapshots import rank_candidates


def candidate(identifier: str, utmos: float, whisqa: float, wer: float) -> dict:
    return {
        "id": identifier,
        "checkpoint": f"/tmp/{identifier}.pt",
        "checkpoint_sha256": "0" * 64,
        "count": 100,
        "utmos_mean": utmos,
        "whisqa_mean": whisqa,
        "wer_percent": wer,
    }


class RankVocoderSnapshotTests(unittest.TestCase):
    def test_selects_paired_mos_gain_with_wer_gate(self) -> None:
        result = rank_candidates(
            [
                candidate("baseline", 2.5, 2.6, 7.0),
                candidate("better", 2.7, 2.8, 7.1),
                candidate("mos_only", 3.0, 3.0, 8.0),
            ],
            baseline_id="baseline",
            min_utmos_gain=0.05,
            min_whisqa_gain=0.05,
            max_wer_regression=0.25,
        )
        self.assertEqual(result["selected_id"], "better")
        eligible = {
            row["id"]: row["eligible"] for row in result["candidates"]
        }
        self.assertTrue(eligible["better"])
        self.assertFalse(eligible["mos_only"])

    def test_falls_back_to_baseline_when_no_candidate_is_eligible(self) -> None:
        result = rank_candidates(
            [
                candidate("baseline", 2.5, 2.6, 7.0),
                candidate("worse", 2.4, 2.5, 7.0),
            ],
            baseline_id="baseline",
            min_utmos_gain=0.05,
            min_whisqa_gain=0.05,
            max_wer_regression=0.25,
        )
        self.assertEqual(result["selected_id"], "baseline")


if __name__ == "__main__":
    unittest.main()
