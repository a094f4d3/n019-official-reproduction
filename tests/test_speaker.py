import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np
import torch

from n019.extract_speakers import load_partial_embeddings
from n019.speaker import SpeakerEmbedder


class _CaptureModel(torch.nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.samples = 0

    def forward(self, waveform: torch.Tensor) -> torch.Tensor:
        self.samples = int(waveform.shape[1])
        return torch.ones(1, 250)


class SpeakerTests(unittest.TestCase):
    def test_wpro_truncates_to_model_card_limit(self) -> None:
        embedder = object.__new__(SpeakerEmbedder)
        embedder.kind = "nt"
        embedder.device = torch.device("cpu")
        embedder.dimension = 250
        embedder.classifier = None
        embedder.nt_max_samples = 100
        embedder.model = _CaptureModel()
        waveform = torch.sin(torch.linspace(0, 20, 250))

        embedding = embedder.embed(waveform, 16_000)

        self.assertEqual(embedder.model.samples, 100)
        self.assertEqual(tuple(embedding.shape), (250,))
        self.assertTrue(bool(torch.isfinite(embedding).all()))

    def test_partial_embedding_resume_round_trip(self) -> None:
        with TemporaryDirectory() as directory:
            path = Path(directory) / "partial_embeddings.npz"
            np.savez(path, speaker_a=np.arange(250, dtype=np.float32))

            values = load_partial_embeddings(path, level="speaker")

        self.assertEqual(set(values), {"speaker_a"})
        self.assertEqual(tuple(values["speaker_a"].shape), (250,))


if __name__ == "__main__":
    unittest.main()
