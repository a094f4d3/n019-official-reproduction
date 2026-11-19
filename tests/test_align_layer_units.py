from __future__ import annotations

import unittest

import numpy as np

from scripts.align_layer_units import cooccurrence_mapping


def row(identifier: str, codes: list[int], tmp: str, *, stem: str) -> dict:
    path = f"{tmp}/{stem}.npy"
    np.save(path, np.array(codes, dtype=np.int16))
    return {"id": identifier, "codes_path": path}


class AlignLayerUnitsTests(unittest.TestCase):
    def test_mapping_recovers_a_permutation(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            reference = row(
                "utt", [0, 0, 1, 1, 2, 2], tmp, stem="reference"
            )
            target = row("utt", [2, 2, 0, 0, 1, 1], tmp, stem="target")
            reference_ids, target_ids = cooccurrence_mapping(
                [reference],
                [target],
                k=3,
            )
            assignment = dict(zip(target_ids.tolist(), reference_ids.tolist()))
            self.assertEqual(assignment, {2: 0, 0: 1, 1: 2})


if __name__ == "__main__":
    unittest.main()
