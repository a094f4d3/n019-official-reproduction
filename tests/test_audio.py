from __future__ import annotations

import unittest

import torch

from n019.audio import (
    collapse_consecutive,
    expand_units,
    expected_hubert_frames,
    round_durations_with_residual,
    sanitize_predicted_durations,
    vpc_loudness_block_size,
)


class AudioTests(unittest.TestCase):
    def test_collapse_and_expand(self) -> None:
        units = torch.tensor([20, 20, 20, 11, 25, 25])
        collapsed, durations = collapse_consecutive(units)
        self.assertEqual(collapsed.tolist(), [20, 11, 25])
        self.assertEqual(durations.tolist(), [3, 1, 2])
        self.assertEqual(expand_units(collapsed, durations).tolist(), units.tolist())

    def test_rounding_preserves_total(self) -> None:
        predicted = torch.tensor([1.4, 1.4, 1.4])
        rounded = round_durations_with_residual(predicted, minimum_one=False)
        self.assertEqual(rounded.tolist(), [1, 2, 1])
        self.assertEqual(int(rounded.sum()), round(float(predicted.sum())))

    def test_rounding_rejects_negative(self) -> None:
        with self.assertRaises(ValueError):
            round_durations_with_residual(torch.tensor([1.0, -0.1]))

    def test_negative_regression_predictions_are_counted_and_clamped(self) -> None:
        sanitized, count = sanitize_predicted_durations(
            torch.tensor([1.0, -0.1, 2.0])
        )
        self.assertEqual(sanitized.tolist(), [1.0, 0.0, 2.0])
        self.assertEqual(count, 1)

    def test_minimum_one_deficit_is_carried(self) -> None:
        predicted = torch.tensor([0.2, 0.2, 3.0])
        rounded = round_durations_with_residual(predicted, minimum_one=True)
        self.assertEqual(rounded.tolist(), [1, 1, 1])
        self.assertEqual(int(rounded.sum()), round(float(predicted.sum())))

    def test_empty_units(self) -> None:
        units, durations = collapse_consecutive(torch.tensor([], dtype=torch.long))
        self.assertEqual(units.numel(), 0)
        self.assertEqual(durations.numel(), 0)

    def test_hubert_length_formula(self) -> None:
        self.assertEqual(expected_hubert_frames(16_000), 49)
        self.assertEqual(expected_hubert_frames(16_000 + 320), 50)

    def test_vpc_loudness_window(self) -> None:
        self.assertAlmostEqual(vpc_loudness_block_size(0.2), 0.1)
        self.assertAlmostEqual(vpc_loudness_block_size(0.3), 0.2)
        self.assertAlmostEqual(vpc_loudness_block_size(2.0), 0.4)
        with self.assertRaises(ValueError):
            vpc_loudness_block_size(0.0)


if __name__ == "__main__":
    unittest.main()
