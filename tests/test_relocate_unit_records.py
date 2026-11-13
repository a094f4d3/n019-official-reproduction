from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.relocate_unit_records import relocate_rows


class RelocateUnitRecordsTests(unittest.TestCase):
    def test_relocates_codes_path(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old = root / "old"
            new = root / "new"
            code = new / "codes" / "utt.npy"
            code.parent.mkdir(parents=True)
            code.write_bytes(b"code")
            rows, changed = relocate_rows(
                [{"codes_path": str(old / "codes" / "utt.npy")}],
                old_root=old,
                new_root=new,
                validate=True,
            )
            self.assertEqual(changed, 1)
            self.assertEqual(rows[0]["codes_path"], str(code.resolve()))

    def test_rejects_path_outside_old_root(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaisesRegex(ValueError, "outside both roots"):
                relocate_rows(
                    [{"codes_path": str(root / "other" / "utt.npy")}],
                    old_root=root / "old",
                    new_root=root / "new",
                    validate=False,
                )

    def test_relocates_audio_and_codebook_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old = root / "old"
            new = root / "new"
            files = {
                "audio": new / "corpora" / "utt.wav",
                "codes_path": new / "codes" / "utt.npy",
                "kmeans_codebook": new / "codebook.npz",
            }
            for field, path in files.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(field.encode("ascii"))
            row = {
                "audio": str(old / "corpora" / "utt.wav"),
                "codes_path": str(old / "codes" / "utt.npy"),
                "kmeans_codebook": str(old / "codebook.npz"),
            }
            rows, changed = relocate_rows(
                [row],
                old_root=old,
                new_root=new,
                validate=True,
            )
            self.assertEqual(changed, 3)
            for field, path in files.items():
                self.assertEqual(rows[0][field], str(path.resolve()))

    def test_accepts_mixed_old_and_new_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old = root / "old"
            new = root / "new"
            audio = new / "corpora" / "utt.wav"
            code = new / "codes" / "utt.npy"
            codebook = new / "codebook.npz"
            for path in (audio, code, codebook):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"ok")
            rows, changed = relocate_rows(
                [
                    {
                        "audio": str(old / "corpora" / "utt.wav"),
                        "codes_path": str(code),
                        "kmeans_codebook": str(codebook),
                    }
                ],
                old_root=old,
                new_root=new,
                validate=True,
            )
            self.assertEqual(changed, 1)
            self.assertEqual(rows[0]["audio"], str(audio.resolve()))
            self.assertEqual(rows[0]["codes_path"], str(code.resolve()))
            self.assertEqual(rows[0]["kmeans_codebook"], str(codebook.resolve()))


if __name__ == "__main__":
    unittest.main()
