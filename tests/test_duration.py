from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import numpy as np
import torch

from n019.duration import (
    DurationDataset,
    DurationModelConfig,
    UnitDurationPredictor,
    collate_duration,
    duration_objective,
    load_duration_checkpoint,
    output_is_pristine,
    save_duration_checkpoint,
)


class DurationTests(unittest.TestCase):
    def test_training_mask_shape_with_padding(self) -> None:
        model = UnitDurationPredictor(
            DurationModelConfig(masking_rate=0.2)
        )
        units = torch.tensor([[1, 2, 3, 200]], dtype=torch.long)
        speakers = torch.randn(1, 250)

        prediction = model(units, speakers)

        self.assertEqual(tuple(prediction.shape), (1, 4))
        self.assertTrue(bool(torch.isfinite(prediction).all()))

    def test_conditioned_shape_and_finite(self) -> None:
        model = UnitDurationPredictor(
            DurationModelConfig(speaker_dim=250)
        ).eval()
        units = torch.randint(0, 200, (3, 17))
        speaker = torch.randn(3, 250)
        with torch.inference_mode():
            prediction = model(units, speaker)
        self.assertEqual(prediction.shape, units.shape)
        self.assertTrue(bool(torch.isfinite(prediction).all()))

    def test_unconditioned_shape(self) -> None:
        model = UnitDurationPredictor(
            DurationModelConfig(speaker_dim=0)
        ).eval()
        units = torch.randint(0, 200, (3, 17))
        with torch.inference_mode():
            prediction = model(units)
        self.assertEqual(prediction.shape, units.shape)
        self.assertIsNone(model.speaker_projection)

    def test_default_structure_matches_dissc_reference(self) -> None:
        config = DurationModelConfig()
        model = UnitDurationPredictor(config)
        self.assertEqual(config.unit_embedding_dim, 32)
        self.assertEqual(config.hidden_dim, 128)
        self.assertEqual(config.num_layers, 7)
        self.assertEqual(config.window_size, 4)
        self.assertEqual(config.window_stride, 4)
        self.assertEqual(config.window_loss_weight, 0.5)
        self.assertEqual(model.unit_embedding.embedding_dim, 32)
        self.assertEqual(len(model.convs), 7)
        self.assertEqual(model.convs[0].in_channels, 64)
        self.assertEqual(model.convs[0].out_channels, 128)
        self.assertEqual(model.speaker_projection.out_features, 32)
        self.assertEqual(model.output.out_channels, 1)

    def test_duration_statistics_are_part_of_inference(self) -> None:
        model = UnitDurationPredictor(
            DurationModelConfig(speaker_dim=0)
        ).eval()
        with torch.no_grad():
            model.output.weight.zero_()
            model.output.bias.zero_()
        model.set_duration_statistics(mean=3.5, std=2.0)
        units = torch.randint(0, 200, (2, 9))
        with torch.inference_mode():
            prediction = model(units)
        self.assertTrue(torch.allclose(prediction, torch.full_like(prediction, 3.5)))

    def test_checkpoint_round_trip(self) -> None:
        model = UnitDurationPredictor(
            DurationModelConfig(speaker_dim=192)
        ).eval()
        model.set_duration_statistics(2.5, 0.75)
        optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
        units = torch.randint(0, 200, (2, 11))
        speaker = torch.randn(2, 192)
        with torch.inference_mode():
            expected = model(units, speaker)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duration.pt"
            save_duration_checkpoint(
                path,
                model,
                optimizer,
                epoch=1,
                best_dev=0.5,
                training_config={"embedding_kind": "ecapa"},
            )
            restored, checkpoint = load_duration_checkpoint(
                path,
                device=torch.device("cpu"),
            )
        with torch.inference_mode():
            actual = restored(units, speaker)
        self.assertTrue(torch.allclose(expected, actual))
        self.assertEqual(
            checkpoint["training_config"]["embedding_kind"],
            "ecapa",
        )
        self.assertAlmostEqual(float(restored.duration_mean), 2.5)
        self.assertAlmostEqual(float(restored.duration_std), 0.75)

    def test_one_batch_backward(self) -> None:
        model = UnitDurationPredictor(
            DurationModelConfig(speaker_dim=250, masking_rate=0.0)
        ).train()
        units = torch.randint(0, 200, (2, 8))
        speaker = torch.randn(2, 250)
        target = torch.full((2, 8), 2.0)
        mask = torch.ones_like(target, dtype=torch.bool)
        prediction = model(units, speaker)
        loss, _, _ = duration_objective(prediction, target, mask)
        loss.backward()
        gradient_norm = sum(
            float(parameter.grad.square().sum())
            for parameter in model.parameters()
            if parameter.grad is not None
        )
        self.assertGreater(gradient_norm, 0.0)

    def test_unconditioned_collate_has_no_speaker_batch(self) -> None:
        units, durations, speakers = collate_duration(
            [
                (torch.tensor([1, 2]), torch.tensor([2.0, 1.0]), None),
                (torch.tensor([3]), torch.tensor([4.0]), None),
            ],
            padding_unit_id=200,
        )
        self.assertEqual(units.shape, (2, 2))
        self.assertEqual(durations.shape, (2, 2))
        self.assertIsNone(speakers)

    def test_dataset_derives_run_lengths_and_statistics(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            codes_path = root / "codes.npy"
            np.save(codes_path, np.array([1, 1, 2, 3, 3, 3], dtype=np.int16))
            records_path = root / "records.jsonl"
            records_path.write_text(
                '{"id":"u1","speaker":"s1","audio":"u1.wav",'
                f'"codes_path":"{codes_path.as_posix()}"}}\n',
                encoding="utf-8",
            )
            dataset = DurationDataset(records_path, None)
            units, durations, speaker = dataset[0]
            mean, std = dataset.duration_statistics()
        self.assertEqual(units.tolist(), [1, 2, 3])
        self.assertEqual(durations.tolist(), [2.0, 1.0, 3.0])
        self.assertIsNone(speaker)
        self.assertAlmostEqual(mean, 2.0)
        self.assertAlmostEqual(std, (2.0 / 3.0) ** 0.5)

    def test_four_unit_loss_compensates_local_errors(self) -> None:
        target = torch.tensor([[2.0, 2.0, 2.0, 2.0]])
        prediction = torch.tensor([[1.5, 2.5, 1.0, 3.0]])
        mask = torch.ones_like(target, dtype=torch.bool)
        _, point, window = duration_objective(
            prediction,
            target,
            mask,
            window_size=4,
        )
        self.assertGreater(float(point), 0.0)
        self.assertAlmostEqual(float(window), 0.0, places=7)

    def test_masked_frames_are_ignored(self) -> None:
        target = torch.tensor([[2.0, 2.0, 0.0]])
        prediction = torch.tensor([[2.0, 2.0, 100.0]])
        mask = torch.tensor([[True, True, False]])
        _, point, _ = duration_objective(prediction, target, mask)
        self.assertEqual(float(point), 0.0)

    def test_four_unit_windows_are_non_overlapping(self) -> None:
        target = torch.tensor([[2.0, 2.0, 2.0, 2.0, 5.0, 5.0, 5.0, 5.0]])
        prediction = torch.tensor([[1.0, 3.0, 2.0, 2.0, 7.0, 5.0, 5.0, 1.0]])
        mask = torch.ones_like(target, dtype=torch.bool)
        loss, point, window = duration_objective(prediction, target, mask)
        # DISSC sums point/window errors and normalises the final loss by the
        # number of valid unit positions, not by the number of windows.
        expected_point = 22.0 / 8.0
        expected_window = 4.0 / 8.0
        self.assertAlmostEqual(float(point), expected_point, places=7)
        self.assertAlmostEqual(float(window), expected_window, places=7)
        self.assertAlmostEqual(
            float(loss),
            expected_point + 0.5 * expected_window,
            places=7,
        )

    def test_window_loss_uses_valid_frame_normalisation(self) -> None:
        target = torch.tensor([[2.0, 2.0, 2.0, 2.0, 5.0, 5.0, 0.0, 0.0]])
        prediction = torch.tensor([[1.0, 3.0, 2.0, 2.0, 7.0, 5.0, 50.0, 50.0]])
        mask = torch.tensor([[True, True, True, True, True, True, False, False]])
        _, point, window = duration_objective(prediction, target, mask)
        self.assertAlmostEqual(float(point), 1.0, places=7)
        self.assertAlmostEqual(float(window), 0.0, places=7)

    def test_launch_metadata_does_not_block_fresh_training(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertTrue(output_is_pristine(root))
            (root / "launch.txt").write_text("scope=test\n", encoding="utf-8")
            self.assertTrue(output_is_pristine(root))
            (root / "last.pt").write_bytes(b"checkpoint")
            self.assertFalse(output_is_pristine(root))


if __name__ == "__main__":
    unittest.main()
