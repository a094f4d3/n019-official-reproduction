from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

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

    def test_allow_nonunit_preserves_raw_ecapa_vector(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target_map = root / "target_map.jsonl"
            embeddings = root / "embeddings.npz"
            out = root / "out.npz"
            summary = root / "summary.json"
            target_map.write_text(
                '{"source_id":"u1","target_speaker":"spk1"}\n',
                encoding="utf-8",
            )
            np.savez_compressed(
                embeddings,
                spk1=np.array([3.0, 4.0], dtype=np.float32),
            )
            subprocess.run(
                [
                    sys.executable,
                    str(Path(__file__).parents[1] / "scripts" / "subset_target_embeddings.py"),
                    "--target-map",
                    str(target_map),
                    "--embeddings",
                    str(embeddings),
                    "--key",
                    "target_speaker",
                    "--dimension",
                    "2",
                    "--allow-nonunit",
                    "--out",
                    str(out),
                    "--summary",
                    str(summary),
                ],
                check=True,
            )
            selected = np.load(out, allow_pickle=False)
            try:
                self.assertEqual(float(np.linalg.norm(selected["spk1"])), 5.0)
            finally:
                selected.close()


if __name__ == "__main__":
    unittest.main()
