from __future__ import annotations

import importlib.util
import unittest

import torch

from n019.spectral import mel_spectrogram


@unittest.skipUnless(
    importlib.util.find_spec("librosa") is not None,
    "librosa is required for the reference mel frontend",
)
class SpectralTests(unittest.TestCase):
    def test_reference_mel_shape(self) -> None:
        waveform = torch.randn(2, 8_960)
        mel = mel_spectrogram(waveform)
        self.assertEqual(mel.shape[0], 2)
        self.assertEqual(mel.shape[1], 80)
        self.assertEqual(mel.shape[2], 35)
        self.assertTrue(bool(torch.isfinite(mel).all()))

    def test_rejects_non_batched_audio(self) -> None:
        with self.assertRaises(ValueError):
            mel_spectrogram(torch.zeros(8_960))

    def test_explicit_rfft_matches_torch_stft(self) -> None:
        import librosa

        waveform = torch.randn(2, 8_960)
        window = torch.hann_window(1024)
        padded = torch.nn.functional.pad(
            waveform.unsqueeze(1),
            (384, 384),
            mode="reflect",
        ).squeeze(1)
        reference_spectrum = torch.stft(
            padded,
            n_fft=1024,
            hop_length=256,
            win_length=1024,
            window=window,
            center=False,
            pad_mode="reflect",
            normalized=False,
            onesided=True,
            return_complex=True,
        )
        basis = torch.from_numpy(
            librosa.filters.mel(
                sr=16_000,
                n_fft=1024,
                n_mels=80,
                fmin=0.0,
                fmax=8_000.0,
            )
        )
        reference_magnitude = torch.sqrt(
            reference_spectrum.real.square()
            + reference_spectrum.imag.square()
            + 1e-9
        )
        reference = torch.log(
            torch.clamp(
                torch.matmul(basis, reference_magnitude),
                min=1e-5,
            )
        )
        actual = mel_spectrogram(waveform)
        torch.testing.assert_close(actual, reference, rtol=2e-5, atol=2e-5)


if __name__ == "__main__":
    unittest.main()
