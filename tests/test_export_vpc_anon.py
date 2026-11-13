from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

from n019 import export_vpc_anon
from n019.manifest import iter_jsonl, write_jsonl


class ExportVpcAnonTests(unittest.TestCase):
    def test_exports_expected_kaldi_layout(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dataset = root / "data" / "libri_test_trials_f"
            dataset.mkdir(parents=True)
            (dataset / "wav.scp").write_text("utt-1 source.wav\n", encoding="utf-8")
            (dataset / "text").write_text("utt-1 TEST TEXT\n", encoding="utf-8")
            anon_wav = root / "anon" / "utt-1.wav"
            anon_wav.parent.mkdir(parents=True)
            anon_wav.write_bytes(b"not read by the exporter")
            manifest = root / "anon.jsonl"
            write_jsonl(
                manifest,
                [{"id": "utt-1", "audio": str(anon_wav)}],
            )
            argv = sys.argv
            try:
                sys.argv = [
                    "export_vpc_anon",
                    "--vpc-data-dir",
                    str(root / "data"),
                    "--anon-manifest",
                    str(manifest),
                    "--suffix",
                    "_n019",
                    "--dataset-prefix",
                    "libri_test_",
                ]
                self.assertEqual(export_vpc_anon.main(), 0)
            finally:
                sys.argv = argv
            output = root / "data" / "libri_test_trials_f_n019"
            rows = list(iter_jsonl(manifest))
            self.assertEqual(len(rows), 1)
            self.assertEqual(
                (output / "wav.scp").read_text(encoding="utf-8").strip(),
                f"utt-1 {anon_wav.resolve()}",
            )
            self.assertEqual(
                (output / "text").read_text(encoding="utf-8"),
                "utt-1 TEST TEXT\n",
            )

    def test_exact_dataset_name_does_not_export_lookalike(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("libri_test", "libri_test_asr"):
                dataset = root / "data" / name
                dataset.mkdir(parents=True)
                (dataset / "wav.scp").write_text(
                    "utt-1 source.wav\n",
                    encoding="utf-8",
                )
            anon_wav = root / "anon" / "utt-1.wav"
            anon_wav.parent.mkdir(parents=True)
            anon_wav.write_bytes(b"not read by the exporter")
            manifest = root / "anon.jsonl"
            write_jsonl(
                manifest,
                [{"id": "utt-1", "audio": str(anon_wav)}],
            )
            argv = sys.argv
            try:
                sys.argv = [
                    "export_vpc_anon",
                    "--vpc-data-dir",
                    str(root / "data"),
                    "--anon-manifest",
                    str(manifest),
                    "--suffix",
                    "_n019",
                    "--dataset-name",
                    "libri_test",
                ]
                self.assertEqual(export_vpc_anon.main(), 0)
            finally:
                sys.argv = argv
            self.assertTrue(
                (root / "data" / "libri_test_n019" / "wav.scp").is_file()
            )
            self.assertFalse(
                (root / "data" / "libri_test_asr_n019").exists()
            )


if __name__ == "__main__":
    unittest.main()
