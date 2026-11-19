from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from dataclasses import asdict
from pathlib import Path

import torch

from n019.hifigan import GeneratorConfig, UnitSpeakerHiFiGAN
from n019.manifest import sha256_file
from n019.vocoder import UnitVocoderConfig


ROOT = Path(__file__).resolve().parents[1]


class CrossSpeakerCheckpointTests(unittest.TestCase):
    def test_builder_preserves_discriminator_optimizer_and_resets_step(
        self,
    ) -> None:
        config = UnitVocoderConfig(
            speaker_dim=250,
            generator=GeneratorConfig(
                upsample_rates=(2, 2),
                upsample_kernel_sizes=(4, 4),
                upsample_initial_channel=16,
            ),
        )
        model = UnitSpeakerHiFiGAN(
            vocab_size=config.vocabulary_size,
            unit_embedding_dim=config.unit_embedding_dim,
            speaker_dim=config.speaker_dim,
            generator_config=config.generator,
            padding_idx=config.padding_unit_id,
        )
        optimizer_g = torch.optim.AdamW(model.parameters(), lr=2e-4)
        optimizer_d = torch.optim.AdamW(model.parameters(), lr=2e-4)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            full_state = root / "full.pt"
            generator = root / "generator.pt"
            output = root / "out" / "last.pt"
            torch.save(
                {
                    "config": asdict(config),
                    "generator": model.state_dict(),
                    "mpd": {},
                    "msd": {},
                    "optimizer_g": optimizer_g.state_dict(),
                    "optimizer_d": optimizer_d.state_dict(),
                    "scheduler_g": None,
                    "scheduler_d": None,
                    "step": 120,
                    "epoch": 3,
                    "stop_reason": None,
                    "recipe": {"test": True},
                },
                full_state,
            )
            torch.save(
                {
                    "config": asdict(config),
                    "generator": model.state_dict(),
                    "step": 90,
                },
                generator,
            )
            environment = dict(os.environ)
            environment["PYTHONPATH"] = str(ROOT / "src")
            result = subprocess.run(
                [
                    sys.executable,
                    str(
                        ROOT
                        / "scripts"
                        / "build_cross_speaker_finetune_checkpoint.py"
                    ),
                    "--full-state",
                    str(full_state),
                    "--full-state-sha256",
                    sha256_file(full_state),
                    "--generator",
                    str(generator),
                    "--generator-sha256",
                    sha256_file(generator),
                    "--lr",
                    "5e-5",
                    "--speaker-swap-probability",
                    "0.5",
                    "--out",
                    str(output),
                ],
                check=True,
                capture_output=True,
                text=True,
                env=environment,
            )
            report = json.loads(result.stdout)
            rebuilt = torch.load(
                output,
                map_location="cpu",
                weights_only=False,
            )
            output_sha256 = sha256_file(output)
        self.assertEqual(report["sha256"], output_sha256)
        self.assertEqual(rebuilt["step"], 0)
        self.assertEqual(rebuilt["epoch"], 0)
        self.assertEqual(rebuilt["config"]["learning_rate"], 5e-5)
        self.assertEqual(rebuilt["config"]["speaker_swap_probability"], 0.5)
        self.assertEqual(
            rebuilt["cross_speaker_initialization"]["generator_sha256"],
            report["generator_sha256"],
        )
        self.assertEqual(
            rebuilt["optimizer_d"]["param_groups"][0]["lr"],
            5e-5,
        )
        self.assertFalse(rebuilt["optimizer_g"]["state"])


if __name__ == "__main__":
    unittest.main()
