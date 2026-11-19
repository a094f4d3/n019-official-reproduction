"""Functional subset of torchaudio used by the vendored code."""

import math

import torch
import torch.nn.functional as F


def resample(
    waveform: torch.Tensor,
    orig_freq: int,
    new_freq: int,
    lowpass_filter_width: int = 6,
    rolloff: float = 0.99,
    resampling_method: str = "sinc_interp_hann",
    beta: float | None = None,
) -> torch.Tensor:
    del lowpass_filter_width, rolloff, resampling_method, beta
    if orig_freq <= 0 or new_freq <= 0:
        raise ValueError("orig_freq and new_freq must be positive")
    if orig_freq == new_freq:
        return waveform
    if waveform.ndim not in {1, 2}:
        raise ValueError("waveform must have shape [time] or [channels, time]")
    unbatched = waveform.ndim == 1
    batched = waveform.unsqueeze(0) if unbatched else waveform
    target_length = int(math.floor(batched.shape[-1] * new_freq / orig_freq))
    if target_length <= 0:
        output = batched[..., :0]
    else:
        output = F.interpolate(
            batched.unsqueeze(1),
            size=target_length,
            mode="linear",
            align_corners=False,
        ).squeeze(1)
    return output.squeeze(0) if unbatched else output


def amplitude_to_db(
    x: torch.Tensor,
    multiplier: float = 20.0,
    amin: float = 1e-5,
    top_db: float | None = 80.0,
) -> torch.Tensor:
    x_db = multiplier * torch.log10(torch.clamp(x, min=amin))
    if top_db is not None:
        x_db = torch.maximum(x_db, x_db.amax() - float(top_db))
    return x_db


def power_to_db(
    x: torch.Tensor,
    multiplier: float = 10.0,
    amin: float = 1e-10,
    top_db: float | None = 80.0,
) -> torch.Tensor:
    return amplitude_to_db(x, multiplier=multiplier, amin=amin, top_db=top_db)
