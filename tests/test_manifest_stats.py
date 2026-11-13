from __future__ import annotations

import unittest

from n019.manifest_stats import summarize_manifest


class ManifestStatsTests(unittest.TestCase):
    def test_summarises_audio_workload(self) -> None:
        result = summarize_manifest(
            [
                {
                    "speaker": "a",
                    "seconds": 2.0,
                    "sample_rate": 16000,
                    "channels": 1,
                },
                {
                    "speaker": "b",
                    "seconds": 4.0,
                    "sample_rate": 16000,
                    "channels": 1,
                },
            ]
        )
        self.assertEqual(result["rows"], 2)
        self.assertEqual(result["speakers"], 2)
        self.assertEqual(result["seconds"], 6.0)
        self.assertEqual(result["mean_seconds"], 3.0)
        self.assertEqual(result["sample_rates"], [16000])
        self.assertEqual(result["channels"], [1])

    def test_rejects_empty_manifest(self) -> None:
        with self.assertRaisesRegex(ValueError, "empty"):
            summarize_manifest([])


if __name__ == "__main__":
    unittest.main()
