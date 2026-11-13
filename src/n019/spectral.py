"""HiFi-GAN mel-spectrogram frontend matching the cited implementation."""

from __future__ import annotations

import torch
import torch.nn.functional as F


_MEL_BASIS: dict[tuple, torch.Tensor] = {}
_WINDOWS: dict[tuple, torch.Tensor] = {}
_DFT_BASIS: dict[tuple, tuple[torch.Tensor, torch.Tensor]] = {}


def mel_spectrogram(
    waveform: torch.Tensor,
    *,
    n_fft: int = 1024,
    num_mels: int = 80,
    sample_rate: int = 16_000,
    hop_size: int = 256,
    win_size: int = 1024,
    f_min: float = 0.0,
    f_max: float | None = 8_000.0,
    center: bool = False,
) -> torch.Tensor:
    """Return log-mel features with shape [batch, mels, frames]."""
    if waveform.ndim != 2:
        raise ValueError("waveform must have shape [batch, samples]")
    if f_max is None:
        f_max = sample_rate / 2
    basis_key = (
        sample_rate,
        n_fft,
        num_mels,
        f_min,
        f_max,
        str(waveform.device),
        waveform.dtype,
    )
    window_key = (
        win_size,
        str(waveform.device),
        waveform.dtype,
    )
    if basis_key not in _MEL_BASIS:
        import librosa

        basis = librosa.filters.mel(
            sr=sample_rate,
            n_fft=n_fft,
            n_mels=num_mels,
            fmin=f_min,
            fmax=f_max,
        )
        _MEL_BASIS[basis_key] = torch.from_numpy(basis).to(
            device=waveform.device,
            dtype=torch.float32,
        )
    if window_key not in _WINDOWS:
        _WINDOWS[window_key] = torch.hann_window(
            win_size,
            device=waveform.device,
            dtype=waveform.dtype,
        )

    pad = (n_fft - hop_size) // 2
    waveform = F.pad(waveform.unsqueeze(1), (pad, pad), mode="reflect").squeeze(1)
    # SCNet's DTK build can reject FP32 stft/rfft plans with
    # HIPFFT_PARSE_ERROR on some nodes. The real DFT below is mathematically
    # equivalent for center=False, uses only matmul, and remains
    # differentiable without depending on hipFFT.
    if center:
        raise ValueError("center=True is not supported by the explicit frontend")
    frames = waveform.unfold(
        dimension=1,
        size=win_size,
        step=hop_size,
    )
    if basis_key not in _DFT_BASIS:
        positions = torch.arange(
            n_fft,
            dtype=torch.float64,
            device="cpu",
        ).unsqueeze(1)
        frequencies = torch.arange(
            n_fft // 2 + 1,
            dtype=torch.float64,
            device="cpu",
        ).unsqueeze(0)
        angles = (
            2.0
            * torch.pi
            * positions
            * frequencies
            / float(n_fft)
        )
        _DFT_BASIS[basis_key] = (
            torch.cos(angles).to(
                device=waveform.device,
                dtype=torch.float32,
            ),
            torch.sin(angles).to(
                device=waveform.device,
                dtype=torch.float32,
            ),
        )
    cos_basis, sin_basis = _DFT_BASIS[basis_key]
    windowed = (frames * _WINDOWS[window_key]).to(torch.float32)
    real = torch.matmul(windowed, cos_basis)
    imag = -torch.matmul(windowed, sin_basis)
    magnitude = torch.sqrt(
        real.square() + imag.square() + 1e-9
    ).transpose(1, 2)
    mel = torch.matmul(_MEL_BASIS[basis_key], magnitude)
    return torch.log(torch.clamp(mel, min=1e-5))
