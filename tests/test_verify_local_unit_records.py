from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from scripts.verify_local_unit_records import verify_records


class VerifyLocalUnitRecordsTests(unittest.TestCase):
    def test_paths_must_be_inside_root_and_present(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            codes = root / "codes.npy"
            codes.write_bytes(b"codes")
            record = root / "records.jsonl"
            record.write_text(
                json.dumps(
                    {
                        "audio": str(root / "audio.wav"),
                        "codes_path": str(codes),
                        "kmeans_codebook": str(codes),
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            (root / "audio.wav").write_bytes(b"audio")
            result = verify_records(
                record,
                root,
                ("audio", "codes_path", "kmeans_codebook"),
            )
        self.assertEqual(result["records"], 1)

    def test_foreign_path_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            record = root / "records.jsonl"
            record.write_text(
                json.dumps(
                    {
                        "audio": "/another/account/audio.wav",
                        "codes_path": "/another/account/codes.npy",
                        "kmeans_codebook": "/another/account/book.npz",
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            with self.assertRaises(ValueError):
                verify_records(
                    record,
                    root,
                    ("audio", "codes_path", "kmeans_codebook"),
                )

    def test_explicit_shared_root_is_allowed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            root = base / "account"
            shared = base / "shared"
            root.mkdir()
            shared.mkdir()
            asset = shared / "asset.bin"
            asset.write_bytes(b"asset")
            record = root / "records.jsonl"
            record.write_text(
                json.dumps(
                    {
                        "audio": str(asset),
                        "codes_path": str(asset),
                        "kmeans_codebook": str(asset),
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            result = verify_records(
                record,
                root,
                ("audio", "codes_path", "kmeans_codebook"),
                (shared,),
            )
        self.assertEqual(result["records"], 1)
        self.assertEqual(result["outside_root"], 0)


if __name__ == "__main__":
    unittest.main()
