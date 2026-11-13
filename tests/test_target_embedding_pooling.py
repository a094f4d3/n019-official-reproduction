from __future__ import annotations

import unittest

import numpy as np

from n019.target_embedding_pooling import pool_target_embeddings


class TargetEmbeddingPoolingTests(unittest.TestCase):
    def test_mean_then_l2_with_target_id_keys(self) -> None:
        embeddings = {
            "u1": np.array([1.0, 0.0], dtype=np.float32),
            "u2": np.array([0.0, 2.0], dtype=np.float32),
            "u3": np.array([1.0, 1.0], dtype=np.float32),
        }
        target_to_speaker = {"u1": "s1", "u2": "s1", "u3": "s2"}
        speaker_to_targets = {"s1": {"u1", "u2"}, "s2": {"u3"}}

        pooled, report = pool_target_embeddings(
            embeddings,
            target_to_speaker,
            speaker_to_targets,
            key_mode="target_id",
        )

        expected_s1 = np.array([1.0, 2.0], dtype=np.float32)
        expected_s1 /= np.linalg.norm(expected_s1)
        np.testing.assert_allclose(pooled["u1"], expected_s1, rtol=1e-6)
        np.testing.assert_allclose(pooled["u2"], expected_s1, rtol=1e-6)
        self.assertEqual(report["target_speakers"], 2)
        self.assertEqual(report["output_keys"], 3)
        self.assertAlmostEqual(report["norm_min"], 1.0, places=5)

    def test_speaker_keys_have_one_vector_per_speaker(self) -> None:
        embeddings = {
            "u1": np.array([1.0, 0.0], dtype=np.float32),
            "u2": np.array([1.0, 0.0], dtype=np.float32),
        }
        pooled, report = pool_target_embeddings(
            embeddings,
            {"u1": "s1", "u2": "s1"},
            {"s1": {"u1", "u2"}},
            key_mode="target_speaker",
        )
        self.assertEqual(set(pooled), {"s1"})
        self.assertEqual(report["output_keys"], 1)

    def test_missing_target_embedding_fails(self) -> None:
        with self.assertRaisesRegex(KeyError, "no embedding"):
            pool_target_embeddings(
                {"u1": np.array([1.0, 0.0], dtype=np.float32)},
                {"u1": "s1", "u2": "s2"},
                {"s1": {"u1"}, "s2": {"u2"}},
                key_mode="target_speaker",
            )


if __name__ == "__main__":
    unittest.main()
