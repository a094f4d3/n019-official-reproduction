from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from n019.anonymize import (
    ensure_output_dir_available,
    estimate_pcm16_wav_bytes,
    extrapolate_durations,
    load_anonymize_resume,
    require_free_space,
    scale_speaker_embedding,
)
from n019.manifest import safe_filename
import torch


class AnonymizeResumeTests(unittest.TestCase):
    def test_scales_speaker_embedding(self) -> None:
        embedding = torch.tensor([0.5, -1.0])
        scaled = scale_speaker_embedding(embedding, 1.5)
        torch.testing.assert_close(scaled, torch.tensor([0.75, -1.5]))
        with self.assertRaisesRegex(ValueError, "finite"):
            scale_speaker_embedding(embedding, float("nan"))
        with self.assertRaisesRegex(ValueError, "positive"):
            scale_speaker_embedding(embedding, 0.0)

    def test_extrapolates_and_preserves_predicted_total(self) -> None:
        predicted = torch.tensor([2.0, 4.0, 3.0])
        original = torch.tensor([3.0, 2.0, 3.0])
        adjusted, negative = extrapolate_durations(
            predicted,
            original,
            0.5,
            preserve_total=True,
        )
        self.assertEqual(negative, 0)
        self.assertAlmostEqual(float(adjusted.sum()), float(predicted.sum()), 5)
        self.assertLess(float(adjusted[0]), 2.0)
        self.assertGreater(float(adjusted[1]), 4.0)
        with self.assertRaisesRegex(ValueError, "non-negative"):
            extrapolate_durations(predicted, original, -0.1, preserve_total=False)

    def test_soft_cap_limits_extreme_duration_change(self) -> None:
        predicted = torch.tensor([2.0, 3.0])
        original = torch.tensor([20.0, 1.0])
        adjusted, negative = extrapolate_durations(
            predicted,
            original,
            0.5,
            preserve_total=False,
            soft_cap_frames=1.0,
        )
        self.assertEqual(negative, 0)
        self.assertTrue(
            bool(((adjusted - predicted).abs() <= 1.0001).all())
        )
        self.assertTrue(bool((adjusted > 0.0).all()))

    def test_allows_launcher_metadata_in_new_output_dir(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            out_dir = Path(directory)
            (out_dir / "launch.txt").write_text("launch\n", encoding="utf-8")
            (out_dir / "stdout.log").write_text("log\n", encoding="utf-8")
            ensure_output_dir_available(
                out_dir,
                overwrite=False,
                resume=False,
            )

    def test_rejects_unrelated_existing_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            out_dir = Path(directory)
            (out_dir / "old.wav").write_bytes(b"RIFF")
            with self.assertRaisesRegex(FileExistsError, "not empty"):
                ensure_output_dir_available(
                    out_dir,
                    overwrite=False,
                    resume=False,
                )

    def test_estimates_pcm16_output_size(self) -> None:
        self.assertEqual(
            estimate_pcm16_wav_bytes(1.0),
            16_000 * 2 + 44,
        )
        with self.assertRaisesRegex(ValueError, "non-negative"):
            estimate_pcm16_wav_bytes(-1.0)

    def test_rejects_insufficient_free_space(self) -> None:
        require_free_space(required_bytes=100, available_bytes=100)
        with self.assertRaisesRegex(OSError, "Insufficient"):
            require_free_space(required_bytes=101, available_bytes=100)

    def test_loads_matching_resume_row(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            out_dir = Path(directory)
            identifier = "19-198-0000"
            audio = out_dir / safe_filename(identifier, ".wav")
            audio.write_bytes(b"RIFF")
            partial = out_dir / "anon.partial.jsonl"
            row = {
                "id": identifier,
                "audio": str(audio),
                "duration_mode": "pred",
                "vocoder_type": "nt",
            }
            partial.write_text(json.dumps(row) + "\n", encoding="utf-8")

            loaded = load_anonymize_resume(
                partial,
                source_ids={identifier},
                out_dir=out_dir,
                duration_mode="pred",
                vocoder_type="nt",
            )

            self.assertEqual(loaded, [row])

    def test_rejects_mode_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            out_dir = Path(directory)
            identifier = "19-198-0000"
            audio = out_dir / safe_filename(identifier, ".wav")
            audio.write_bytes(b"RIFF")
            partial = out_dir / "anon.partial.jsonl"
            partial.write_text(
                json.dumps(
                    {
                        "id": identifier,
                        "audio": str(audio),
                        "duration_mode": "orig",
                        "vocoder_type": "nt",
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "Duration mode mismatch"):
                load_anonymize_resume(
                    partial,
                    source_ids={identifier},
                    out_dir=out_dir,
                    duration_mode="pred",
                    vocoder_type="nt",
                )

    def test_rejects_missing_audio(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            out_dir = Path(directory)
            identifier = "19-198-0000"
            audio = out_dir / safe_filename(identifier, ".wav")
            partial = out_dir / "anon.partial.jsonl"
            partial.write_text(
                json.dumps(
                    {
                        "id": identifier,
                        "audio": str(audio),
                        "duration_mode": "pred",
                        "vocoder_type": "nt",
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            with self.assertRaises(FileNotFoundError):
                load_anonymize_resume(
                    partial,
                    source_ids={identifier},
                    out_dir=out_dir,
                    duration_mode="pred",
                    vocoder_type="nt",
                )

    def test_rejects_target_embedding_mode_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            out_dir = Path(directory)
            identifier = "19-198-0000"
            audio = out_dir / safe_filename(identifier, ".wav")
            audio.write_bytes(b"RIFF")
            partial = out_dir / "anon.partial.jsonl"
            partial.write_text(
                json.dumps(
                    {
                        "id": identifier,
                        "audio": str(audio),
                        "duration_mode": "pred",
                        "vocoder_type": "nt",
                        "target_embedding_key": "target_id",
                        "target_embedding_mode": "utterance",
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(
                ValueError,
                "Target embedding mode mismatch",
            ):
                load_anonymize_resume(
                    partial,
                    source_ids={identifier},
                    out_dir=out_dir,
                    duration_mode="pred",
                    vocoder_type="nt",
                    target_embedding_key="target_id",
                    target_embedding_mode="speaker_mean_l2",
                )

    def test_rejects_duration_embedding_key_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            out_dir = Path(directory)
            identifier = "19-198-0000"
            audio = out_dir / safe_filename(identifier, ".wav")
            audio.write_bytes(b"RIFF")
            partial = out_dir / "anon.partial.jsonl"
            partial.write_text(
                json.dumps(
                    {
                        "id": identifier,
                        "audio": str(audio),
                        "duration_mode": "nt",
                        "duration_embedding_key": "target_id",
                        "vocoder_type": "nt",
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(
                ValueError,
                "Duration embedding key mismatch",
            ):
                load_anonymize_resume(
                    partial,
                    source_ids={identifier},
                    out_dir=out_dir,
                    duration_mode="nt",
                    vocoder_type="nt",
                    duration_embedding_key="target_speaker",
                )


if __name__ == "__main__":
    unittest.main()
