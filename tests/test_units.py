from __future__ import annotations

import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np
import torch

from n019.units import (
    KMeansCodebook,
    feature_output_length,
    load_resume_records,
    save_array_atomic,
)
from n019.manifest import safe_filename


class UnitTests(unittest.TestCase):
    def test_atomic_array_save_writes_exact_npy(self) -> None:
        with TemporaryDirectory() as directory:
            path = Path(directory) / "codes" / "utterance.npy"
            expected = np.array([1, 2, 3], dtype=np.int16)

            save_array_atomic(path, expected)

            actual = np.load(path)
            self.assertFalse(path.with_suffix(".npy.tmp").exists())
        np.testing.assert_array_equal(actual, expected)

    def test_nearest_centroid_assignment(self) -> None:
        codebook = KMeansCodebook(
            torch.tensor(
                [
                    [0.0, 0.0],
                    [10.0, 10.0],
                    [-10.0, -10.0],
                ]
            )
        )
        features = torch.tensor(
            [
                [0.1, 0.2],
                [9.5, 10.5],
                [-11.0, -9.0],
            ]
        )
        labels = codebook.assign(features, device=torch.device("cpu"), chunk_size=2)
        self.assertEqual(labels.tolist(), [0, 1, 2])

    def test_invalid_centroid_shape(self) -> None:
        with self.assertRaises(ValueError):
            KMeansCodebook(torch.zeros(3))

    def test_utterance_filename_is_windows_safe_and_unique(self) -> None:
        first = safe_filename("ls100:19-198-0000", ".npy")
        second = safe_filename("ls100:19-198-0001", ".npy")
        self.assertNotIn(":", first)
        self.assertNotEqual(first, second)
        self.assertTrue(first.endswith(".npy"))

    def test_hubert_output_length_formula(self) -> None:
        strides = (5, 2, 2, 2, 2, 2, 2)
        kernels = (10, 3, 3, 3, 3, 2, 2)
        self.assertEqual(feature_output_length(16_000, strides, kernels), 49)
        self.assertEqual(feature_output_length(16_320, strides, kernels), 50)

    def test_resume_records_are_validated_and_loaded(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            code_dir = root / "codes"
            code_dir.mkdir()
            identifier = "19-198-0000"
            code_path = code_dir / safe_filename(identifier, ".npy")
            save_array_atomic(code_path, np.array([1, 2], dtype=np.int16))
            codebook_path = root / "codebook.npz"
            codebook_path.write_bytes(b"NPZ")
            records_path = root / "unit_records.partial.jsonl"
            record = {
                "id": identifier,
                "codes_path": str(code_path),
                "num_frames": 2,
                "kmeans_k": 200,
                "hubert_layer": 6,
                "kmeans_codebook": str(codebook_path),
            }
            records_path.write_text(json.dumps(record) + "\n", encoding="utf-8")

            loaded = load_resume_records(
                records_path,
                valid_ids={identifier},
                code_dir=code_dir,
                k=200,
                layer=6,
                codebook_path=codebook_path,
            )

            self.assertEqual(loaded, [record])

    def test_resume_rejects_duplicate_record(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            code_dir = root / "codes"
            code_dir.mkdir()
            identifier = "19-198-0000"
            code_path = code_dir / safe_filename(identifier, ".npy")
            save_array_atomic(code_path, np.array([1, 2], dtype=np.int16))
            record = {
                "id": identifier,
                "codes_path": str(code_path),
                "num_frames": 2,
                "kmeans_k": 200,
                "hubert_layer": 6,
            }
            records_path = root / "unit_records.partial.jsonl"
            records_path.write_text(
                json.dumps(record) + "\n" + json.dumps(record) + "\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "Duplicate resume record"):
                load_resume_records(
                    records_path,
                    valid_ids={identifier},
                    code_dir=code_dir,
                    k=200,
                    layer=6,
                )

    def test_resume_rejects_missing_code_file(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            code_dir = root / "codes"
            code_dir.mkdir()
            identifier = "19-198-0000"
            code_path = code_dir / safe_filename(identifier, ".npy")
            record = {
                "id": identifier,
                "codes_path": str(code_path),
                "num_frames": 2,
                "kmeans_k": 200,
                "hubert_layer": 6,
            }
            records_path = root / "unit_records.partial.jsonl"
            records_path.write_text(json.dumps(record) + "\n", encoding="utf-8")

            with self.assertRaises(FileNotFoundError):
                load_resume_records(
                    records_path,
                    valid_ids={identifier},
                    code_dir=code_dir,
                    k=200,
                    layer=6,
                )


if __name__ == "__main__":
    unittest.main()
