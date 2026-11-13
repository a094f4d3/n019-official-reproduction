from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from n019.eval_mos import collect_audio_items, summarize_scores


class EvalMosTests(unittest.TestCase):
    def test_collect_deduplicates_identical_utterances(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            audio = root / "a.wav"
            audio.write_bytes(b"not read by this test")
            first = root / "first.scp"
            second = root / "second.scp"
            first.write_text(f"utt-a {audio}\n", encoding="utf-8")
            second.write_text(f"utt-a {audio}\n", encoding="utf-8")
            items = collect_audio_items(
                [first, second],
                vpc_data_root=None,
            )
            self.assertEqual(len(items), 1)
            self.assertEqual(items[0].utterance_id, "utt-a")

    def test_collect_rejects_conflicting_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            first_audio = root / "a.wav"
            second_audio = root / "b.wav"
            first_audio.write_bytes(b"a")
            second_audio.write_bytes(b"b")
            first = root / "first.scp"
            second = root / "second.scp"
            first.write_text(f"utt-a {first_audio}\n", encoding="utf-8")
            second.write_text(f"utt-a {second_audio}\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Conflicting paths"):
                collect_audio_items(
                    [first, second],
                    vpc_data_root=None,
                )

    def test_collect_rejects_pipe_commands(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            scp = root / "wav.scp"
            scp.write_text("utt-a flac -d -c a.flac |\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "materialised WAV"):
                collect_audio_items([scp], vpc_data_root=None)

    def test_summary_uses_mean_and_records_provenance(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            checkpoint = root / "model.pt"
            checkpoint.write_bytes(b"checkpoint")
            source = root / "source"
            source.mkdir()
            (source / "model.py").write_text("VALUE = 1\n", encoding="utf-8")
            scp = root / "wav.scp"
            scp.write_text("utt-a a.wav\n", encoding="utf-8")
            summary = summarize_scores(
                [
                    {"id": "utt-a", "score": 2.0},
                    {"id": "utt-b", "score": 4.0},
                ],
                metric="UTMOS",
                backend="utmos",
                model_path=checkpoint,
                code_source=source,
                input_sha256={str(scp): "abc"},
            )
            self.assertEqual(summary["count"], 2)
            self.assertEqual(summary["mean"], 3.0)
            self.assertIn("model.py", summary["code_sha256"])
            self.assertEqual(summary["input_sha256"][str(scp)], "abc")


if __name__ == "__main__":
    unittest.main()
