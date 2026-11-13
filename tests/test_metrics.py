from __future__ import annotations

import unittest

import numpy as np

from n019.metrics import corpus_wer, equal_error_rate


class MetricTests(unittest.TestCase):
    def test_eer_perfect_separation(self) -> None:
        result = equal_error_rate(
            np.array([1, 1, 0, 0]),
            np.array([0.9, 0.8, 0.2, 0.1]),
        )
        self.assertEqual(result["eer"], 0.0)

    def test_corpus_wer(self) -> None:
        result = corpus_wer(
            ["the quick brown fox", "hello world"],
            ["the quick fox", "hello there"],
        )
        self.assertEqual(result["errors"], 2)
        self.assertEqual(result["words"], 6)


if __name__ == "__main__":
    unittest.main()
