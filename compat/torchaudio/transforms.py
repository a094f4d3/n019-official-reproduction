"""Transform subset of torchaudio used by the vendored PhonePuRe code."""

import librosa
import numpy as np
import torch
import torch.nn as nn

from .functional import amplitude_to_db, resample


class Resample(nn.Module):
    def __init__(
        self,
        orig_freq: int = 16000,
        new_freq: int = 16000,
        resampling_method: str = "sinc_interp_hann",
        lowpass_filter_width: int = 6,
        rolloff: float = 0.99,
        beta: float | None = None,
    ):
        super().__init__()
        self.orig_freq = int(orig_freq)
        self.new_freq = int(new_freq)
        self.resampling_method = resampling_method
        self.lowpass_filter_width = lowpass_filter_width
        self.rolloff = rolloff
        self.beta = beta

    def forward(self, waveform: torch.Tensor) -> torch.Tensor:
        return resample(
            waveform,
            self.orig_freq,
            self.new_freq,
            lowpass_filter_width=self.lowpass_filter_width,
            rolloff=self.rolloff,
            resampling_method=self.resampling_method,
            beta=self.beta,
        )


class MelSpectrogram(nn.Module):
    def __init__(
        self,
        sample_rate: int = 16000,
        n_fft: int = 400,
        win_length: int | None = None,
        hop_length: int | None = None,
        f_min: float = 0.0,
        f_max: float | None = None,
        pad: int = 0,
        n_mels: int = 128,
        window_fn=torch.hann_window,
        power: float = 2.0,
        normalized: bool = False,
        wkwargs=None,
        center: bool = True,
        pad_mode: str = "reflect",
        onesided: bool = True,
        norm=None,
        mel_scale: str = "htk",
    ):
        super().__init__()
        del window_fn, wkwargs, onesided
        self.sample_rate = int(sample_rate)
        self.n_fft = int(n_fft)
        self.win_length = int(win_length or n_fft)
        self.hop_length = int(hop_length or n_fft // 4)
        self.f_min = float(f_min)
        self.f_max = float(f_max) if f_max is not None else float(sample_rate // 2)
        self.pad = int(pad)
        self.n_mels = int(n_mels)
        self.power = float(power)
        self.normalized = normalized
        self.center = center
        self.pad_mode = pad_mode
        self.norm = "slaney" if norm == "slaney" else None
        self.mel_scale = mel_scale

        basis = librosa.filters.mel(
            sr=self.sample_rate,
            n_fft=self.n_fft,
            n_mels=self.n_mels,
            fmin=self.f_min,
            fmax=self.f_max,
            norm=self.norm,
            htk=(mel_scale == "htk"),
        )
        self.register_buffer("mel_basis", torch.from_numpy(basis).float())

    def forward(self, waveform: torch.Tensor) -> torch.Tensor:
        if waveform.ndim == 1:
            waveform = waveform.unsqueeze(0)
        if self.pad:
            waveform = torch.nn.functional.pad(
                waveform.unsqueeze(1), (self.pad, self.pad), mode=self.pad_mode
            ).squeeze(1)
        window = torch.hann_window(
            self.win_length, device=waveform.device, dtype=waveform.dtype
        )
        spectrum = torch.stft(
            waveform,
            n_fft=self.n_fft,
            hop_length=self.hop_length,
            win_length=self.win_length,
            window=window,
            center=self.center,
            pad_mode=self.pad_mode,
            return_complex=True,
        )
        magnitude = spectrum.abs()
        if self.power == 1.0:
            return torch.matmul(self.mel_basis.to(magnitude), magnitude)
        return torch.matmul(
            self.mel_basis.to(magnitude), magnitude.pow(self.power)
        )


class AmplitudeToDB(nn.Module):
    def __init__(
        self,
        stype: str = "power",
        top_db: float | None = None,
    ):
        super().__init__()
        self.stype = stype
        self.top_db = top_db

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        multiplier = 10.0 if self.stype == "power" else 20.0
        return amplitude_to_db(x, multiplier=multiplier, top_db=self.top_db)
