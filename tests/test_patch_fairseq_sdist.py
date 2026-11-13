from __future__ import annotations

import unittest

from scripts.patch_fairseq_sdist import patch_setup_source


SETUP = """\
extensions = []
try:
    extensions.extend(
        [
            cpp_extension.CppExtension("fairseq.libbase"),
        ]
    )

    extensions.extend(
        [
            cpp_extension.CppExtension("fairseq.libnat"),
            cpp_extension.CppExtension("alignment_train_cpu_binding"),
        ]
    )
    if "CUDA_HOME" in os.environ:
        extensions.extend(
            [
                cpp_extension.CppExtension("fairseq.libnat_cuda"),
            ]
        )
    cmdclass["build_ext"] = cpp_extension.BuildExtension
except ImportError:
    pass
"""


class PatchFairseqSdistTests(unittest.TestCase):
    def test_removes_optional_extension_blocks(self) -> None:
        patched = patch_setup_source(SETUP)
        self.assertEqual(patched.count("extensions.extend("), 1)
        self.assertIn("extensions = []", patched)
        self.assertIn('if "CUDA_HOME" in os.environ:', patched)
        self.assertIn('cmdclass["build_ext"]', patched)
        self.assertIn("except ImportError", patched)

    def test_rejects_unexpected_setup(self) -> None:
        with self.assertRaisesRegex(ValueError, "three extensions"):
            patch_setup_source("extensions = []\n")


if __name__ == "__main__":
    unittest.main()
