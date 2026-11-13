"""Synthesize anonymized speech from one extracted unit record."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import soundfile as sf
import torch

from n019.audio import expand_units, round_durations_with_residual
from n019.duration import load_duration_checkpoint
from n019.vocoder import load_generator


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--record", required=True)
    parser.add_argument("--speaker-embeddings", required=True)
    parser.add_argument("--target-speaker", required=True)
    parser.add_argument("--vocoder", required=True)
    parser.add_argument("--duration", default=None)
    parser.add_argument("--duration-mode", choices=["orig", "pred"], required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--device", default="cuda")
    parser.add_argument("--duration-blend", type=float, default=1.0)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not 0.0 <= args.duration_blend <= 1.0:
        raise ValueError("--duration-blend must be in [0, 1]")
    device = torch.device(args.device)
    generator, _ = load_generator(args.vocoder, device)

    embeddings = np.load(args.speaker_embeddings)
    target = torch.from_numpy(
        embeddings[args.target_speaker].astype(np.float32)
    ).unsqueeze(0).to(device)
    with open(args.record, encoding="utf-8") as handle:
        row = json.load(handle)
    units = torch.tensor(row["collapsed_units"], dtype=torch.long)
    durations = torch.tensor(row["durations"], dtype=torch.long)

    if args.duration_mode == "pred":
        if not args.duration:
            raise ValueError("--duration is required for predicted durations")
        predictor, checkpoint = load_duration_checkpoint(
            args.duration,
            device=device,
        )
        if checkpoint["model_config"]["speaker_dim"] != 0:
            raise ValueError(
                "This utility's --duration-mode pred requires an "
                "unconditional duration checkpoint"
            )
        with torch.inference_mode():
            predicted = predictor(units.unsqueeze(0).to(device))[0].cpu()
        original = durations.float()
        predicted = (
            args.duration_blend * predicted
            + (1.0 - args.duration_blend) * original
        )
        durations = round_durations_with_residual(predicted, minimum_one=True)

    expanded = expand_units(units, durations).unsqueeze(0).to(device)
    with torch.inference_mode():
        waveform = generator(expanded, target)[0, 0].float().cpu().numpy()
    sf.write(args.out, waveform, 16_000)
    print(args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
