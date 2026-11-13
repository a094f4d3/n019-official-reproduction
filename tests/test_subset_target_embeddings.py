from __future__ import annotations

import unittest

import numpy as np


class SubsetTargetEmbeddingTests(unittest.TestCase):
    def test_selected_vectors_are_unit_norm(self) -> None:
        vectors = {
            "u1": np.array([1.0, 0.0], dtype=np.float32),
            "u2": np.array([0.0, 1.0], dtype=np.float32),
        }
        selected = {key: vectors[key] for key in ("u1",)}
        self.assertEqual(set(selected), {"u1"})
        self.assertAlmostEqual(
            float(np.linalg.norm(selected["u1"])),
            1.0,
        )


if __name__ == "__main__":
    unittest.main()
