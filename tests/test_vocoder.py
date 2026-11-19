from __future__ import annotations

import tempfile
import unittest
import json
import sys
import types
from pathlib import Path
from unittest import mock

import numpy as np
import torch

from n019.audio import HOP_SAMPLES
from n019.hifigan import GeneratorConfig, UnitSpeakerHiFiGAN
from n019.vocoder import (
    UnitVocoderConfig,
    UnitVocoderDataset,
    load_generator,
    output_directory_conflicts,
    save_generator_checkpoint,
    save_vocoder_checkpoint,
    update_validation_best,
    validation_converged,
)


class VocoderCheckpointTests(unittest.TestCase):
    def test_dataset_scales_speaker_embedding(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            codes_path = root / "codes.npy"
            embeddings_path = root / "speakers.npz"
            records_path = root / "records.jsonl"
            np.save(codes_path, np.arange(4, dtype=np.int64))
            np.savez(
                embeddings_path,
                speaker=np.array([1.0, -2.0], dtype=np.float32),
            )
            records_path.write_text(
                json.dumps(
                    {
                        "id": "utt",
                        "speaker": "speaker",
                        "audio": str(root / "unused.wav"),
                        "codes_path": str(codes_path),
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            waveform = torch.linspace(
                -0.5,
                0.5,
                4 * HOP_SAMPLES,
            )
            fake_librosa = types.SimpleNamespace(
                util=types.SimpleNamespace(normalize=lambda value: value)
            )
            with (
                mock.patch.dict(sys.modules, {"librosa": fake_librosa}),
                mock.patch(
                    "n019.vocoder.load_audio_16k",
                    return_value=waveform,
                ),
            ):
                dataset = UnitVocoderDataset(
                    records_path,
                    embeddings_path,
                    segment_frames=4,
                    padding_unit_id=200,
                    embedding_level="speaker",
                    speaker_embedding_scale=1.5,
                    speaker_swap_probability=0.0,
                    speaker_swap_embeddings_path=None,
                    random_crop=False,
                    seed=1,
                )
                _, _, speaker = dataset[0]
        torch.testing.assert_close(
            speaker,
            torch.tensor([1.5, -3.0]),
        )

    def test_dataset_can_swap_source_speaker_during_training(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            codes_path = root / "codes.npy"
            embeddings_path = root / "speakers.npz"
            records_path = root / "records.jsonl"
            np.save(codes_path, np.arange(4, dtype=np.int64))
            np.savez(
                embeddings_path,
                source=np.array([1.0, 0.0], dtype=np.float32),
                target=np.array([0.0, 1.0], dtype=np.float32),
            )
            records_path.write_text(
                json.dumps(
                    {
                        "id": "utt",
                        "speaker": "source",
                        "audio": str(root / "unused.wav"),
                        "codes_path": str(codes_path),
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            waveform = torch.linspace(
                -0.5,
                0.5,
                4 * HOP_SAMPLES,
            )
            fake_librosa = types.SimpleNamespace(
                util=types.SimpleNamespace(normalize=lambda value: value)
            )
            with (
                mock.patch.dict(sys.modules, {"librosa": fake_librosa}),
                mock.patch(
                    "n019.vocoder.load_audio_16k",
                    return_value=waveform,
                ),
            ):
                dataset = UnitVocoderDataset(
                    records_path,
                    embeddings_path,
                    segment_frames=4,
                    padding_unit_id=200,
                    embedding_level="speaker",
                    speaker_embedding_scale=1.0,
                    speaker_swap_probability=1.0,
                    speaker_swap_embeddings_path=None,
                    random_crop=True,
                    seed=1,
                )
                _, _, speaker = dataset[0]
        torch.testing.assert_close(
            speaker,
            torch.tensor([0.0, 1.0]),
        )

    def test_dataset_uses_external_swap_archive(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            codes_path = root / "codes.npy"
            embeddings_path = root / "speakers.npz"
            swap_path = root / "swap.npz"
            records_path = root / "records.jsonl"
            np.save(codes_path, np.arange(4, dtype=np.int64))
            np.savez(
                embeddings_path,
                source=np.array([1.0, 0.0], dtype=np.float32),
            )
            np.savez(
                swap_path,
                external=np.array([0.0, 1.0], dtype=np.float32),
            )
            records_path.write_text(
                json.dumps(
                    {
                        "id": "utt",
                        "speaker": "source",
                        "audio": str(root / "unused.wav"),
                        "codes_path": str(codes_path),
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            waveform = torch.linspace(
                -0.5,
                0.5,
                4 * HOP_SAMPLES,
            )
            fake_librosa = types.SimpleNamespace(
                util=types.SimpleNamespace(normalize=lambda value: value)
            )
            with (
                mock.patch.dict(sys.modules, {"librosa": fake_librosa}),
                mock.patch(
                    "n019.vocoder.load_audio_16k",
                    return_value=waveform,
                ),
            ):
                dataset = UnitVocoderDataset(
                    records_path,
                    embeddings_path,
                    segment_frames=4,
                    padding_unit_id=200,
                    embedding_level="speaker",
                    speaker_embedding_scale=1.0,
                    speaker_swap_probability=1.0,
                    speaker_swap_embeddings_path=swap_path,
                    random_crop=True,
                    seed=1,
                )
                _, _, speaker = dataset[0]
                source_dataset = UnitVocoderDataset(
                    records_path,
                    embeddings_path,
                    segment_frames=4,
                    padding_unit_id=200,
                    embedding_level="speaker",
                    speaker_embedding_scale=1.0,
                    speaker_swap_probability=0.0,
                    speaker_swap_embeddings_path=swap_path,
                    random_crop=True,
                    seed=1,
                )
                _, _, source_speaker = source_dataset[0]
        torch.testing.assert_close(
            speaker,
            torch.tensor([0.0, 1.0]),
        )
        torch.testing.assert_close(
            source_speaker,
            torch.tensor([1.0, 0.0]),
        )

    def test_validation_tracker_and_convergence_threshold(self) -> None:
        best, best_step, stale, improved = update_validation_best(
            metric=1.0,
            step=2000,
            best_metric=None,
            best_step=0,
            validations_without_improvement=0,
            min_delta=0.01,
        )
        self.assertTrue(improved)
        self.assertEqual((best, best_step, stale), (1.0, 2000, 0))

        best, best_step, stale, improved = update_validation_best(
            metric=0.995,
            step=4000,
            best_metric=best,
            best_step=best_step,
            validations_without_improvement=stale,
            min_delta=0.01,
        )
        self.assertFalse(improved)
        self.assertEqual((best, best_step, stale), (1.0, 2000, 1))
        self.assertFalse(
            validation_converged(
                step=4000,
                validations_without_improvement=stale,
                patience=2,
                min_steps=20_000,
            )
        )
        self.assertTrue(
            validation_converged(
                step=20_000,
                validations_without_improvement=2,
                patience=2,
                min_steps=20_000,
            )
        )

    def test_launch_metadata_does_not_block_fresh_run(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory)
            (out / "launch.txt").write_text("launch\n", encoding="utf-8")
            self.assertEqual(output_directory_conflicts(out), [])

    def test_unknown_output_file_blocks_fresh_run(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory)
            (out / "launch.txt").write_text("launch\n", encoding="utf-8")
            (out / "stale.pt").write_bytes(b"stale")
            self.assertEqual(output_directory_conflicts(out), ["stale.pt"])

    def test_last_checkpoint_allows_resume_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory)
            (out / "launch.txt").write_text("launch\n", encoding="utf-8")
            (out / "last.pt").write_bytes(b"checkpoint")
            (out / "training_log.jsonl").write_text("{}\n", encoding="utf-8")
            self.assertEqual(output_directory_conflicts(out), [])

    def test_generator_checkpoint_round_trip(self) -> None:
        config = UnitVocoderConfig(
            speaker_dim=250,
            generator=GeneratorConfig(
                upsample_rates=(2, 2),
                upsample_kernel_sizes=(4, 4),
                upsample_initial_channel=16,
            ),
        )
        generator = UnitSpeakerHiFiGAN(
            vocab_size=config.vocabulary_size,
            unit_embedding_dim=config.unit_embedding_dim,
            speaker_dim=config.speaker_dim,
            generator_config=config.generator,
            padding_idx=config.padding_unit_id,
        )
        optimizer = torch.optim.AdamW(generator.parameters(), lr=1e-4)
        units = torch.randint(0, 200, (1, 5))
        speaker = torch.randn(1, 250)
        with torch.inference_mode():
            expected = generator.eval()(units, speaker)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "vocoder.pt"
            save_vocoder_checkpoint(
                path,
                config=config,
                generator=generator,
                mpd=torch.nn.Identity(),
                msd=torch.nn.Identity(),
                optimizer_g=optimizer,
                optimizer_d=optimizer,
                scheduler_g=None,
                scheduler_d=None,
                step=12,
                epoch=1,
                best_validation_mel_l1=0.75,
                best_validation_step=10,
                validations_without_improvement=2,
                stop_reason="max_hours",
            )
            restored, checkpoint = load_generator(path, torch.device("cpu"))
        with torch.inference_mode():
            actual = restored(units, speaker)
        self.assertTrue(torch.allclose(expected, actual))
        self.assertEqual(checkpoint["step"], 12)
        self.assertEqual(checkpoint["config"]["speaker_dim"], 250)
        self.assertEqual(checkpoint["best_validation_mel_l1"], 0.75)
        self.assertEqual(checkpoint["validations_without_improvement"], 2)
        self.assertEqual(checkpoint["stop_reason"], "max_hours")

    def test_compact_best_checkpoint_round_trip(self) -> None:
        config = UnitVocoderConfig(
            speaker_dim=192,
            generator=GeneratorConfig(
                upsample_rates=(2, 2),
                upsample_kernel_sizes=(4, 4),
                upsample_initial_channel=16,
            ),
        )
        generator = UnitSpeakerHiFiGAN(
            vocab_size=config.vocabulary_size,
            unit_embedding_dim=config.unit_embedding_dim,
            speaker_dim=config.speaker_dim,
            generator_config=config.generator,
            padding_idx=config.padding_unit_id,
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "best.pt"
            save_generator_checkpoint(
                path,
                config=config,
                generator=generator,
                step=30,
                epoch=2,
                validation_mel_l1=0.625,
            )
            restored, checkpoint = load_generator(path, torch.device("cpu"))
        self.assertEqual(checkpoint["step"], 30)
        self.assertEqual(checkpoint["validation_mel_l1"], 0.625)
        self.assertEqual(
            sum(parameter.numel() for parameter in restored.parameters()),
            sum(parameter.numel() for parameter in generator.parameters()),
        )


if __name__ == "__main__":
    unittest.main()
