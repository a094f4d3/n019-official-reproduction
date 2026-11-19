"""Small torchaudio compatibility layer for the SCNet DTK environment.

PyTorch from the DTK image uses a custom ABI, so the public PyPI torchaudio
wheel cannot load against it.  N010/PhonePuRe only need file I/O and a few
signal transforms in this environment.  Keeping these helpers in a separate
package avoids changing the vendored PhonePuRe source.
"""

from pathlib import Path

import soundfile as sf
import torch

from . import functional, transforms

__version__ = "2.9.0+scnet-compat"


def load(
    filepath,
    frame_offset: int = 0,
    num_frames: int = -1,
    normalize: bool = True,
    channels_first: bool = True,
    format=None,
    backend=None,
    **kwargs,
):
    del normalize, format, backend, kwargs
    audio, sample_rate = sf.read(
        str(Path(filepath)),
        start=max(0, int(frame_offset)),
        frames=-1 if int(num_frames) < 0 else int(num_frames),
        dtype="float32",
        always_2d=True,
    )
    waveform = torch.from_numpy(audio.T.copy())
    if not channels_first:
        waveform = waveform.transpose(0, 1)
    return waveform, int(sample_rate)


def save(
    filepath,
    src,
    sample_rate: int,
    channels_first: bool = True,
    compression=None,
    format=None,
    bits_per_sample=None,
    **kwargs,
):
    del compression, bits_per_sample, kwargs
    waveform = src.detach().cpu() if isinstance(src, torch.Tensor) else src
    if isinstance(waveform, torch.Tensor):
        waveform = waveform.numpy()
    if waveform.ndim == 1:
        waveform = waveform[:, None]
    elif channels_first:
        waveform = waveform.T
    sf.write(
        str(Path(filepath)),
        waveform,
        int(sample_rate),
        format=format,
        subtype="PCM_16",
    )


def info(filepath, backend=None):
    del backend
    data = sf.info(str(Path(filepath)))
    return {
        "sample_rate": data.samplerate,
        "num_frames": data.frames,
        "num_channels": data.channels,
        "bits_per_sample": 16,
        "encoding": data.subtype,
    }


def list_audio_backends():
    return ["soundfile"]


__all__ = [
    "functional",
    "transforms",
    "load",
    "save",
    "info",
    "list_audio_backends",
]
