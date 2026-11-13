from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from make_speaker_uniform_utterance_target_map import (
    deterministic_rng,
    normalize_target_rows,
    unique_targets,
)


class SpeakerUniformUtteranceTargetMapTests(unittest.TestCase):
    def test_rng_is_deterministic_per_source(self) -> None:
        first = deterministic_rng(7, "source-1").random()
        second = deterministic_rng(7, "source-1").random()
        other = deterministic_rng(8, "source-1").random()
        self.assertEqual(first, second)
        self.assertNotEqual(deterministic_rng(7, "source-2").random(), first)
        self.assertIsInstance(other, float)

    def test_duplicate_target_speaker_conflict_is_rejected(self) -> None:
        rows = [
            {"target_id": "u1", "target_speaker": "s1"},
            {"target_id": "u1", "target_speaker": "s2"},
        ]
        with self.assertRaisesRegex(ValueError, "multiple speakers"):
            unique_targets(rows)

    def test_raw_manifest_rows_are_normalized(self) -> None:
        rows = normalize_target_rows(
            [
                {
                    "id": "tts500:1_2_3",
                    "audio": "/data/1/2/3.wav",
                    "speaker": "1",
                }
            ]
        )
        self.assertEqual(rows[0]["target_id"], "tts500:1_2_3")
        self.assertEqual(rows[0]["target_audio"], "/data/1/2/3.wav")
        self.assertEqual(rows[0]["target_speaker"], "1")

    def test_raw_manifest_missing_target_fields_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "Target rows"):
            normalize_target_rows([{"id": "u1"}])


if __name__ == "__main__":
    unittest.main()
