from __future__ import annotations

import unittest

from n019.targets import build_target_map


class TargetTests(unittest.TestCase):
    def test_mapping_is_deterministic(self) -> None:
        sources = [
            {"id": "s1", "speaker": "spk1", "audio": "s1.wav"},
            {"id": "s2", "speaker": "spk1", "audio": "s2.wav"},
        ]
        targets = [
            {"id": "t1", "speaker": "a", "audio": "t1.wav"},
            {"id": "t2", "speaker": "b", "audio": "t2.wav"},
            {"id": "t3", "speaker": "b", "audio": "t3.wav"},
        ]
        first = build_target_map(sources, targets, seed=7)
        second = build_target_map(sources, targets, seed=7)
        self.assertEqual(first, second)
        self.assertEqual(len(first), 2)

    def test_duplicate_source_ids_rejected(self) -> None:
        sources = [
            {"id": "same", "speaker": "a", "audio": "a.wav"},
            {"id": "same", "speaker": "b", "audio": "b.wav"},
        ]
        targets = [{"id": "t", "speaker": "t", "audio": "t.wav"}]
        with self.assertRaises(ValueError):
            build_target_map(sources, targets, seed=1)


if __name__ == "__main__":
    unittest.main()
