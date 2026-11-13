"""Audio and discrete-unit primitives shared by training and inference."""

from __future__ import annotations

import math
from pathlib import Path
from typing import Iterable

import numpy as np
import torch
import torch.nn.functional as F


SAMPLE_RATE = 16_000
HOP_SAMPLES = 320
FRAME_SECONDS = HOP_SAMPLES / SAMPLE_RATE
PAD_UNIT_ID = 200


def read_audio(path: str | Path) -> tuple[torch.Tensor, int]:
    """Read one recording and return mono float32 audio without normalisation."""
    import soundfile as sf

    waveform, sample_rate = sf.read(
        str(path),
        dtype="float32",
        always_2d=True,
    )
    if waveform.shape[1] < 1:
        raise ValueError(f"Audio has no channels: {path}")
    mono = waveform.mean(axis=1, dtype=np.float32)
    if mono.size == 0:
        raise ValueError(f"Audio is empty: {path}")
    return torch.from_numpy(mono), int(sample_rate)


def resample_audio(waveform: torch.Tensor, sample_rate: int) -> torch.Tensor:
    if sample_rate == SAMPLE_RATE:
        return waveform.float()
    import torchaudio

    return torchaudio.functional.resample(
        waveform.float(),
        orig_freq=sample_rate,
        new_freq=SAMPLE_RATE,
    )


def load_audio_16k(path: str | Path) -> torch.Tensor:
    waveform, sample_rate = read_audio(path)
    waveform = resample_audio(waveform, sample_rate)
    if not torch.isfinite(waveform).all():
        raise ValueError(f"Audio contains non-finite samples: {path}")
    return waveform.contiguous()


def load_audio_16k_mono(path: str | Path) -> torch.Tensor:
    """Backward-compatible name for the mono 16 kHz loader."""
    return load_audio_16k(path)


def peak_normalize(waveform: torch.Tensor, peak: float = 0.95) -> torch.Tensor:
    if not 0.0 < peak <= 1.0:
        raise ValueError("peak must be in (0, 1]")
    maximum = float(torch.max(torch.abs(waveform)))
    if maximum <= 1e-8:
        return waveform
    return waveform * (peak / maximum)


def normalize_loudness(
    waveform: torch.Tensor,
    sample_rate: int,
    *,
    target_lufs: float = -30.0,
) -> torch.Tensor:
    """Apply the VPC loudness and peak normalisation used for ECAPA."""
    try:
        import pyloudnorm as pyln
    except ImportError as exc:
        raise RuntimeError(
            "pyloudnorm is required for ECAPA preprocessing"
        ) from exc
    if sample_rate != SAMPLE_RATE:
        waveform = resample_audio(waveform, sample_rate)
    array = waveform.detach().cpu().numpy().astype(np.float64)
    duration = array.size / SAMPLE_RATE
    block_size = vpc_loudness_block_size(duration)
    meter = pyln.Meter(SAMPLE_RATE, block_size=block_size)
    loudness = meter.integrated_loudness(array)
    normalized = pyln.normalize.loudness(array, loudness, target_lufs)
    peak = np.max(np.abs(normalized))
    if peak > 1e-8:
        normalized = normalized / peak
    return torch.from_numpy(normalized.astype(np.float32))


def vpc_loudness_block_size(duration_seconds: float) -> float:
    """Match the block-size rule in VPC2024's official normalize_wave."""
    if not math.isfinite(duration_seconds) or duration_seconds <= 0.0:
        raise ValueError("duration_seconds must be finite and positive")
    if duration_seconds < 0.4:
        block_size = min(
            duration_seconds - 0.0001,
            abs(duration_seconds - 0.1),
        )
    else:
        block_size = 0.4
    if block_size <= 0.0:
        raise ValueError("Audio is too short for VPC loudness normalisation")
    return float(block_size)


def save_audio(path: str | Path, waveform: torch.Tensor) -> None:
    import soundfile as sf

    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    array = waveform.detach().float().cpu().squeeze().numpy()
    if array.ndim != 1:
        raise ValueError("save_audio expects one mono waveform")
    if not np.isfinite(array).all():
        raise ValueError("Refusing to save non-finite audio")
    sf.write(str(destination), np.clip(array, -1.0, 1.0), SAMPLE_RATE)


def collapse_consecutive(
    units: torch.Tensor,
) -> tuple[torch.Tensor, torch.Tensor]:
    """Collapse repeated unit IDs and return the corresponding run lengths."""
    units = torch.as_tensor(units, dtype=torch.long).flatten()
    if units.numel() == 0:
        return units, torch.empty(0, dtype=torch.long)
    changes = torch.ones(units.numel(), dtype=torch.bool, device=units.device)
    changes[1:] = units[1:] != units[:-1]
    starts = torch.nonzero(changes, as_tuple=False).flatten()
    ends = torch.cat(
        [
            starts[1:],
            torch.tensor([units.numel()], dtype=torch.long, device=units.device),
        ]
    )
    return units[starts], ends - starts


def expand_units(units: torch.Tensor, durations: torch.Tensor) -> torch.Tensor:
    units = torch.as_tensor(units, dtype=torch.long).flatten()
    durations = torch.as_tensor(durations, dtype=torch.long).flatten()
    if units.numel() != durations.numel():
        raise ValueError("units and durations must have equal length")
    if durations.numel() == 0:
        return torch.empty(0, dtype=torch.long, device=units.device)
    if bool((durations < 0).any()):
        raise ValueError("durations must be non-negative")
    return torch.repeat_interleave(units, durations)


def round_durations_with_residual(
    predicted: torch.Tensor,
    *,
    minimum_one: bool = True,
) -> torch.Tensor:
    """Round sequentially so fractional errors propagate to later units."""
    predicted = torch.as_tensor(predicted, dtype=torch.float32).flatten()
    if predicted.numel() == 0:
        return torch.empty(0, dtype=torch.long, device=predicted.device)
    if not torch.isfinite(predicted).all():
        raise ValueError("predicted durations must be finite")
    if bool((predicted < 0).any()):
        raise ValueError("predicted durations must be non-negative")
    if not minimum_one or bool((predicted >= 1.0).all()):
        cumulative = torch.round(torch.cumsum(predicted, dim=0)).to(torch.long)
        starts = torch.cat(
            [
                torch.zeros(1, dtype=torch.long, device=predicted.device),
                cumulative[:-1],
            ]
        )
        return cumulative - starts
    rounded = torch.empty_like(predicted, dtype=torch.long)
    remainder = predicted.new_zeros(())
    for index in range(predicted.numel()):
        adjusted = predicted[index] + remainder
        value = torch.round(adjusted)
        if minimum_one:
            value = value.clamp_min(1)
        rounded[index] = value.to(torch.long)
        remainder = adjusted - value
    return rounded


def sanitize_predicted_durations(
    predicted: torch.Tensor,
) -> tuple[torch.Tensor, int]:
    """Clamp invalid negative regression outputs and report how many occurred."""
    predicted = torch.as_tensor(predicted, dtype=torch.float32).flatten()
    if not torch.isfinite(predicted).all():
        raise ValueError("predicted durations must be finite")
    negative = int((predicted < 0).sum().item())
    return predicted.clamp_min(0.0), negative


def pad_1d_sequences(
    sequences: Iterable[torch.Tensor],
    *,
    pad_value: float = 0.0,
) -> tuple[torch.Tensor, torch.Tensor]:
    values = [torch.as_tensor(item).flatten() for item in sequences]
    if not values:
        raise ValueError("No sequences to pad")
    lengths = torch.tensor([item.numel() for item in values], dtype=torch.long)
    return F.pad_sequence(values, batch_first=True, padding_value=pad_value), lengths


def expected_hubert_frames(samples: int) -> int:
    """Output length of HuBERT base's seven convolutional feature layers."""
    length = samples
    for stride, kernel in zip(
        (5, 2, 2, 2, 2, 2, 2),
        (10, 3, 3, 3, 3, 2, 2),
    ):
        length = max(0, (length - kernel) // stride + 1)
    return length


def safe_log(value: torch.Tensor, eps: float = 1e-5) -> torch.Tensor:
    return torch.log(torch.clamp(value, min=eps))


def audio_seconds(samples: int) -> float:
    return samples / SAMPLE_RATE


def frames_to_samples(frames: int) -> int:
    return frames * HOP_SAMPLES


def samples_to_frames(samples: int) -> int:
    return int(math.ceil(samples / HOP_SAMPLES))
