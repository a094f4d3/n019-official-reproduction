from __future__ import annotations

import json
import unittest
from pathlib import Path

from n019.duration import DurationModelConfig
from n019.hifigan import GeneratorConfig
from n019.units import HubertUnitConfig
from n019.vocoder import UnitVocoderConfig


ROOT = Path(__file__).resolve().parents[1]


class PaperAlignmentTests(unittest.TestCase):
    def test_all_json_configs_parse(self) -> None:
        for path in sorted((ROOT / "configs").glob("*.json")):
            with self.subTest(path=path.name):
                json.loads(path.read_text(encoding="utf-8"))

    def test_machine_readable_config_matches_code_defaults(self) -> None:
        config = json.loads(
            (ROOT / "configs" / "paper_algorithm_v1.json").read_text(
                encoding="utf-8"
            )
        )
        commitment = config["paper_commitment"]
        choices = config["implementation_choices"]
        duration = DurationModelConfig()
        generator = GeneratorConfig()
        units = HubertUnitConfig()
        vocoder = UnitVocoderConfig()
        self.assertEqual(commitment["unit_vocabulary_size"], 200)
        self.assertEqual(units.vocabulary_size, 200)
        self.assertEqual(units.layer, 6)
        self.assertEqual(duration.window_size, 4)
        self.assertEqual(duration.window_stride, 4)
        self.assertEqual(
            commitment["target_sampling_mode"],
            "utterance",
        )
        self.assertEqual(
            commitment["target_sampling_pool_rows"],
            205_044,
        )
        self.assertEqual(
            duration.unit_embedding_dim,
            choices["duration_unit_embedding_dim"],
        )
        self.assertEqual(
            duration.num_layers,
            choices["duration_num_conv_layers"],
        )
        self.assertTrue(duration.normalize_durations)
        self.assertEqual(generator.samples_per_frame, 320)
        self.assertEqual(
            generator.upsample_initial_channel,
            choices["vocoder_initial_channel"],
        )
        self.assertEqual(
            vocoder.feature_loss_weight,
            choices["vocoder_feature_loss_weight"],
        )
        self.assertEqual(
            vocoder.learning_rate,
            choices["vocoder_learning_rate"],
        )
        self.assertEqual(
            vocoder.batch_size,
            choices["vocoder_batch_size"],
        )
        self.assertEqual(choices["vocoder_optimizer"], "AdamW")
        self.assertEqual(vocoder.optimizer, "adamw")
        self.assertEqual(vocoder.grad_clip_norm, 0.0)

    def test_vocoder_launcher_supports_utterance_conditioning(self) -> None:
        launcher = (
            ROOT / "scripts" / "run_vocoder_ddp.sh"
        ).read_text(encoding="utf-8")
        self.assertIn(
            'EMBEDDING_LEVEL="${N019_VOCODER_EMBEDDING_LEVEL:-speaker}"',
            launcher,
        )
        self.assertIn(
            '--embedding-level "$EMBEDDING_LEVEL"',
            launcher,
        )
        self.assertNotIn("--embedding-level speaker", launcher)

    def test_snapshot_selection_supports_early_utmos_reject(self) -> None:
        selector = (
            ROOT / "scripts" / "run_vocoder_snapshot_selection_ai.sh"
        ).read_text(encoding="utf-8")
        self.assertIn("N019_SELECTION_EARLY_REJECT_UTMOS", selector)
        self.assertIn(
            '"reason": "utmos_gate_cannot_pass"',
            selector,
        )
        self.assertIn(
            "N019_SELECTION_EARLY_REJECT_UTMOS_GAIN",
            selector,
        )


if __name__ == "__main__":
    unittest.main()
