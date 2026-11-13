"""Cheap spectral sanity check for reconstructed vs source audio."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
import soundfile as sf


def frame_spectrum(mono: np.ndarray, n_fft: int = 1024, hop: int = 512):
    frames = 1 + max(0, (len(mono) - n_fft) // hop)
    index = np.arange(n_fft)[None, :] + hop * np.arange(frames)[:, None]
    windowed = mono[index] * np.hanning(n_fft)[None, :]
    magnitude = np.abs(np.fft.rfft(windowed, axis=1)) + 1e-12
    return magnitude


def summarize(path: Path) -> dict[str, float]:
    audio, sample_rate = sf.read(str(path), dtype="float32", always_2d=True)
    mono = audio.mean(axis=1)
    magnitude = frame_spectrum(mono)
    freqs = np.fft.rfftfreq(1024, d=1.0 / sample_rate)
    power = magnitude**2
    total = power.sum(axis=1) + 1e-18
    centroid = float(np.mean((power * freqs[None, :]).sum(axis=1) / total))
    flatness = float(
        np.mean(np.exp(np.mean(np.log(magnitude), axis=1)) / np.mean(magnitude, axis=1))
    )
    rms = float(np.sqrt(np.mean(np.square(mono, dtype=np.float64)) + 1e-20))
    return {
        "centroid_hz": centroid,
        "spectral_flatness": flatness,
        "rms_dbfs": 20.0 * math.log10(rms),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", required=True)
    parser.add_argument("--limit", type=int, default=10)
    args = parser.parse_args()

    files = sorted(Path(args.dir).glob("*.wav"))[: args.limit]
    if not files:
        raise SystemExit(f"no wav files under {args.dir}")
    stats = [summarize(path) for path in files]
    out = {
        "dir": args.dir,
        "n": len(stats),
        "centroid_hz_mean": float(np.mean([s["centroid_hz"] for s in stats])),
        "spectral_flatness_mean": float(
            np.mean([s["spectral_flatness"] for s in stats])
        ),
        "rms_dbfs_mean": float(np.mean([s["rms_dbfs"] for s in stats])),
    }
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
