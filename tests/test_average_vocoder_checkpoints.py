from __future__ import annotations

import unittest

from scripts.average_vocoder_checkpoints import checkpoint_configs_compatible


class AverageVocoderCheckpointTests(unittest.TestCase):
    def test_default_requires_exact_config_match(self) -> None:
        first = {"speaker_dim": 250, "max_hours": 42.25}
        other = {"speaker_dim": 250, "max_hours": 34.0}
        self.assertFalse(
            checkpoint_configs_compatible(
                first,
                other,
                allow_nonarchitectural_diff=False,
            )
        )

    def test_nonarchitectural_difference_can_be_allowed(self) -> None:
        first = {
            "speaker_dim": 250,
            "generator": {"upsample_initial_channel": 512},
            "max_hours": 42.25,
        }
        other = {
            "speaker_dim": 250,
            "generator": {"upsample_initial_channel": 512},
            "max_hours": 34.0,
        }
        self.assertTrue(
            checkpoint_configs_compatible(
                first,
                other,
                allow_nonarchitectural_diff=True,
            )
        )

    def test_architecture_difference_is_rejected_even_when_allowed(self) -> None:
        first = {"speaker_dim": 250, "generator": {"upsample_initial_channel": 512}}
        other = {"speaker_dim": 192, "generator": {"upsample_initial_channel": 512}}
        self.assertFalse(
            checkpoint_configs_compatible(
                first,
                other,
                allow_nonarchitectural_diff=True,
            )
        )


if __name__ == "__main__":
    unittest.main()
