from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from n019.prepare_train360 import librispeech_fields, vpc_ids


class PrepareTrain360Tests(unittest.TestCase):
    def test_vpc_ids_is_sorted_and_unique(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "wav.scp"
            path.write_text(
                "utt-b flac -d -c b.flac |\nutt-a flac -d -c a.flac |\n",
                encoding="utf-8",
            )
            self.assertEqual(vpc_ids(path), ["utt-a", "utt-b"])

    def test_vpc_ids_rejects_duplicates(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "wav.scp"
            path.write_text(
                "utt-a a.flac\nutt-a b.flac\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "duplicate IDs"):
                vpc_ids(path)

    def test_librispeech_fields_accepts_standard_three_level_layout(self) -> None:
        self.assertEqual(
            librispeech_fields(Path("100/121669/100-121669-0000.flac")),
            ("100", "121669"),
        )

    def test_librispeech_fields_rejects_extra_level(self) -> None:
        with self.assertRaisesRegex(ValueError, "Unexpected LibriSpeech layout"):
            librispeech_fields(Path("train/100/121669/100-121669-0000.flac"))

    def test_librispeech_fields_rejects_filename_mismatch(self) -> None:
        with self.assertRaisesRegex(ValueError, "does not match"):
            librispeech_fields(Path("100/121669/100-121670-0000.flac"))


if __name__ == "__main__":
    unittest.main()
