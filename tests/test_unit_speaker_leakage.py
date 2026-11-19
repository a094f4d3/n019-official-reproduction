from __future__ import annotations

import unittest

import numpy as np

from scripts.analyze_unit_speaker_leakage import (
    normalized_histogram,
    sequence_ngram_text,
    select_rows,
)


def row(speaker: str, utterance: str) -> dict:
    return {
        "id": utterance,
        "speaker": speaker,
        "audio": f"/tmp/{utterance}.wav",
    }


class UnitSpeakerLeakageTests(unittest.TestCase):
    def test_select_rows_is_speaker_balanced_and_disjoint(self) -> None:
        rows = [
            row(f"s{speaker}", f"s{speaker}-u{utterance}")
            for speaker in range(4)
            for utterance in range(6)
        ]
        train, test = select_rows(
            rows,
            speakers=3,
            utterances_per_speaker=4,
            train_per_speaker=3,
            seed=7,
        )
        self.assertEqual(len(train), 9)
        self.assertEqual(len(test), 3)
        self.assertFalse(
            {item["id"] for item in train}
            & {item["id"] for item in test}
        )
        for speaker in {item["speaker"] for item in train}:
            self.assertEqual(
                sum(item["speaker"] == speaker for item in train),
                3,
            )

    def test_normalized_histogram(self) -> None:
        value = normalized_histogram([1, 1, 3], 5)
        np.testing.assert_allclose(value, [0.0, 2 / 3, 0.0, 1 / 3, 0.0])

    def test_histogram_rejects_out_of_range_token(self) -> None:
        with self.assertRaises(ValueError):
            normalized_histogram([0, 5], 5)

    def test_sequence_ngram_text_preserves_order(self) -> None:
        self.assertEqual(sequence_ngram_text([20, 11, 25]), "u20 u11 u25")

    def test_sequence_ngram_text_rejects_empty(self) -> None:
        with self.assertRaises(ValueError):
            sequence_ngram_text([])


if __name__ == "__main__":
    unittest.main()
