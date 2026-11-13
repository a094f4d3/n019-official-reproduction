from __future__ import annotations

import unittest

from n019.training_recipe import (
    EXPECTED_FEATURE_MATCHING_SCALE,
    feature_matching_probe,
    training_recipe_metadata,
    validate_feature_matching_recipe,
)


class TrainingRecipeTests(unittest.TestCase):
    def test_feature_matching_probe_is_two_times_the_reference_sum(self) -> None:
        self.assertEqual(
            feature_matching_probe(),
            2.0 * EXPECTED_FEATURE_MATCHING_SCALE,
        )

    def test_recipe_validation_and_metadata(self) -> None:
        validate_feature_matching_recipe()
        metadata = training_recipe_metadata()
        self.assertEqual(
            metadata["feature_matching_scale"],
            EXPECTED_FEATURE_MATCHING_SCALE,
        )
        self.assertRegex(metadata["hifigan_py_sha256"], r"^[0-9a-f]{64}$")
        self.assertRegex(
            metadata["training_recipe_py_sha256"],
            r"^[0-9a-f]{64}$",
        )


if __name__ == "__main__":
    unittest.main()
