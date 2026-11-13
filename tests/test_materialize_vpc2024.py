from pathlib import Path
from tempfile import TemporaryDirectory
import sys
import types
import unittest

try:
    import soundfile  # noqa: F401
except ModuleNotFoundError:
    sys.modules["soundfile"] = types.ModuleType("soundfile")

from scripts.materialize_vpc2024 import collect_items


class MaterializeVpc2024Tests(unittest.TestCase):
    def test_collect_items_can_select_test_only(self) -> None:
        with TemporaryDirectory() as raw:
            root = Path(raw)
            vpc = root / "vpc"
            librispeech = root / "librispeech"
            for split, utt_id in (
                ("test", "100-100-0000"),
                ("dev", "200-200-0000"),
            ):
                manifest_dir = vpc / "data" / (
                    "libri_test_trials_f" if split == "test" else "libri_dev_trials_f"
                )
                manifest_dir.mkdir(parents=True)
                (manifest_dir / "wav.scp").write_text(
                    f"{utt_id} data/libri_{split}/wav/{utt_id}.wav\n",
                    encoding="utf-8",
                )
                (manifest_dir / "utt2dur").write_text(
                    f"{utt_id} 1.0\n",
                    encoding="utf-8",
                )
                source = (
                    librispeech
                    / f"{split}-clean"
                    / utt_id.split("-")[0]
                    / utt_id.split("-")[1]
                    / f"{utt_id}.flac"
                )
                source.parent.mkdir(parents=True)
                source.write_bytes(b"not-real-flac")

            items, durations = collect_items(vpc, librispeech, 0, "test")

            self.assertEqual([item.utt_id for item in items], ["100-100-0000"])
            self.assertEqual(set(durations), {"100-100-0000"})


if __name__ == "__main__":
    unittest.main()
