from __future__ import annotations

import unittest

import torch

from n019.hifigan import (
    GeneratorConfig,
    UnitSpeakerHiFiGAN,
    feature_matching_loss,
)


class HiFiGANTests(unittest.TestCase):
    def test_unit_speaker_generator_length_and_conditioning(self) -> None:
        config = GeneratorConfig(
            upsample_rates=(2, 2, 2),
            upsample_kernel_sizes=(4, 4, 4),
            upsample_initial_channel=32,
        )
        model = UnitSpeakerHiFiGAN(
            vocab_size=201,
            unit_embedding_dim=8,
            speaker_dim=6,
            generator_config=config,
        ).eval()
        units = torch.randint(0, 200, (2, 9))
        speaker = torch.randn(2, 6)
        with torch.inference_mode():
            output = model(units, speaker)
        self.assertEqual(output.shape, (2, 1, 9 * 8))
        self.assertEqual(model.conditioning_dim, 14)
        self.assertTrue(bool((output.abs() <= 1).all()))

    def test_no_speaker_projection_by_default(self) -> None:
        config = GeneratorConfig(
            upsample_rates=(2, 2, 2),
            upsample_kernel_sizes=(4, 4, 4),
            upsample_initial_channel=16,
        )
        model = UnitSpeakerHiFiGAN(
            vocab_size=201,
            unit_embedding_dim=5,
            speaker_dim=7,
            generator_config=config,
        )
        self.assertEqual(model.conditioning_dim, 12)
        self.assertIsInstance(model.speaker_projection, torch.nn.Identity)

    def test_weight_norm_can_be_removed_for_inference(self) -> None:
        config = GeneratorConfig(
            upsample_rates=(2, 2),
            upsample_kernel_sizes=(4, 4),
            upsample_initial_channel=16,
        )
        model = UnitSpeakerHiFiGAN(
            vocab_size=201,
            unit_embedding_dim=5,
            speaker_dim=7,
            generator_config=config,
        ).eval()
        units = torch.randint(0, 200, (1, 4))
        speaker = torch.randn(1, 7)
        model.remove_weight_norm()
        with torch.inference_mode():
            output = model(units, speaker)
        self.assertEqual(output.shape, (1, 1, 16))

    def test_feature_matching_loss_uses_reference_scale(self) -> None:
        real = [[torch.zeros(1), torch.ones(1)]]
        generated = [[torch.ones(1), torch.zeros(1)]]
        self.assertEqual(float(feature_matching_loss(real, generated)), 4.0)


if __name__ == "__main__":
    unittest.main()
