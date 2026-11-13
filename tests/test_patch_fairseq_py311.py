from __future__ import annotations

import unittest

from scripts.patch_fairseq_py311 import (
    patch_initialize_source,
    patch_module,
    patch_source,
)


SOURCE = """\
@dataclass
class FairseqConfig(FairseqDataclass):
    common: CommonConfig = CommonConfig()
    model: Any = MISSING


class Next:
    pass
"""


class PatchFairseqTests(unittest.TestCase):
    def test_replaces_mutable_config_defaults(self) -> None:
        updated, count = patch_source(SOURCE)
        self.assertEqual(count, 1)
        self.assertIn(
            "common: CommonConfig = field(default_factory=CommonConfig)",
            updated,
        )
        self.assertIn("model: Any = MISSING", updated)
        self.assertNotIn("Next: CommonConfig", updated)

    def test_refuses_source_without_target_class(self) -> None:
        with self.assertRaisesRegex(ValueError, "FairseqConfig"):
            patch_source("class Other:\n    pass\n")

    def test_module_mode_patches_nested_config_defaults(self) -> None:
        updated, count = patch_module(
            "class Config:\n"
            "    encoder: EncDecBaseConfig = EncDecBaseConfig()\n"
            "    noise: NoiseConfig = field(default=NoiseConfig())\n"
        )
        self.assertEqual(count, 2)
        self.assertIn("default_factory=EncDecBaseConfig", updated)
        self.assertIn("field(default_factory=NoiseConfig)", updated)

    def test_initialize_uses_default_factory(self) -> None:
        source = """\
import logging

    for k in FairseqConfig.__dataclass_fields__:
        v = FairseqConfig.__dataclass_fields__[k].default
"""
        updated, count = patch_initialize_source(source)
        self.assertEqual(count, 1)
        self.assertIn("from dataclasses import MISSING", updated)
        self.assertIn("fairseq_field.default_factory", updated)
        self.assertNotIn("FairseqConfig.__dataclass_fields__[k].default", updated)


if __name__ == "__main__":
    unittest.main()
