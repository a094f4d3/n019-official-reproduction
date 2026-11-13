from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from n019.anonymize import (
    ensure_output_dir_available,
    estimate_pcm16_wav_bytes,
    load_anonymize_resume,
    require_free_space,
)
from n019.manifest import safe_filename


class AnonymizeResumeTests(unittest.TestCase):
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
