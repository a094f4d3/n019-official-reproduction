from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import torch

from n019.wnt_attack import (
    AngularMarginHead,
    WntClassifier,
    crop_or_tile,
    freeze_wavlm_trunk,
    load_kaldi_rows,
    resolve_audio,
)


class WntAttackTests(unittest.TestCase):
    def test_crop_tiles_short_audio_to_exact_length(self) -> None:
        waveform = torch.tensor([1.0, 2.0, 3.0])
        cropped = crop_or_tile(waveform, samples=8, start=0)
        self.assertEqual(cropped.numel(), 8)
        self.assertEqual(cropped[0].item(), 1.0)

    def test_kaldi_loader_requires_materialised_audio(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "wav.scp").write_text(
                "utt-a flac -d -c a.flac |\n",
                encoding="utf-8",
            )
            (root / "utt2spk").write_text("utt-a speaker-a\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "materialised WAVs"):
                load_kaldi_rows(root)

    def test_resolve_audio_rejects_pipe(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(ValueError, "materialised WAVs"):
                resolve_audio(Path(temporary), "cat a.wav |")

    def test_aam_margin_changes_target_logit(self) -> None:
        head = AngularMarginHead(
            4,
            3,
            margin=0.5,
            scale=1.0,
        )
        with torch.no_grad():
            head.weight.copy_(
                torch.tensor(
                    [
                        [1.0, 0.0, 0.0, 0.0],
                        [0.0, 1.0, 0.0, 0.0],
                        [0.0, 0.0, 1.0, 0.0],
                    ]
                )
            )
        embeddings = torch.tensor([[1.0, 0.0, 0.0, 0.0]])
        logits = head(embeddings, torch.tensor([0]))
        self.assertLess(float(logits[0, 0].detach()), 1.0)

    def test_classifier_joins_encoder_and_aam_head(self) -> None:
        class DummyEncoder(torch.nn.Module):
            def forward(self, waveforms: torch.Tensor) -> torch.Tensor:
                return torch.nn.functional.normalize(
                    waveforms[:, :4],
                    dim=1,
                )

        head = AngularMarginHead(4, 2, margin=0.0, scale=30.0)
        classifier = WntClassifier(DummyEncoder(), head)
        logits = classifier(
            torch.tensor([[1.0, 0.0, 0.0, 0.0, 9.0]]),
            torch.tensor([0]),
        )
        self.assertEqual(tuple(logits.shape), (1, 2))

    def test_freeze_wavlm_keeps_top_layers_trainable(self) -> None:
        class DummyModel(torch.nn.Module):
            def __init__(self) -> None:
                super().__init__()
                self.wavlm = torch.nn.Linear(3, 4)
                self.top_layers = torch.nn.Linear(4, 2)

        model = DummyModel()
        frozen, trainable = freeze_wavlm_trunk(model)

        self.assertEqual(frozen, 16)
        self.assertEqual(trainable, 10)
        self.assertFalse(any(p.requires_grad for p in model.wavlm.parameters()))
        self.assertTrue(
            all(p.requires_grad for p in model.top_layers.parameters())
        )


if __name__ == "__main__":
    unittest.main()
