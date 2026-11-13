"""CPU/DCU shape probe for the formal N019 model components."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch

from n019.audio import (
    expand_units,
    load_audio_16k,
    round_durations_with_residual,
)
from n019.duration import DurationModelConfig, UnitDurationPredictor
from n019.hifigan import GeneratorConfig, UnitSpeakerHiFiGAN
from n019.speaker import SpeakerEmbedder
from n019.units import HubertFrameExtractor


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", required=True)
    parser.add_argument("--hubert", required=True)
    parser.add_argument("--speaker-model", required=True)
    parser.add_argument("--speaker-kind", choices=["nt", "ecapa"], default="nt")
    parser.add_argument("--out", required=True)
    parser.add_argument("--device", default="cpu")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    device = torch.device(args.device)
    waveform = load_audio_16k(args.audio)
    hubert = HubertFrameExtractor(args.hubert, device, layer=6)
    frames, lengths = hubert.extract([waveform])
    speaker = SpeakerEmbedder(args.speaker_kind, args.speaker_model, device)
    embedding = speaker.embed(waveform)
    duration_model = UnitDurationPredictor(
        DurationModelConfig(speaker_dim=embedding.numel())
    ).to(device).eval()
    # The probe checks tensor contracts, not trained duration quality.
    probe_duration_mean = 2.0
    probe_duration_std = 0.5
    duration_model.set_duration_statistics(
        probe_duration_mean,
        probe_duration_std,
    )
    vocoder = UnitSpeakerHiFiGAN(
        vocab_size=201,
        unit_embedding_dim=128,
        speaker_dim=embedding.numel(),
        generator_config=GeneratorConfig(),
        padding_idx=200,
    ).to(device).eval()
    units = torch.randint(0, 200, (1, 160), device=device)
    with torch.inference_mode():
        durations = duration_model(
            units,
            embedding.unsqueeze(0).to(device),
        )
        rounded = round_durations_with_residual(
            durations[0],
            minimum_one=True,
        )
        expanded = expand_units(units[0], rounded).unsqueeze(0)
        waveform_out = vocoder(expanded, embedding.unsqueeze(0).to(device))
    report = {
        "audio_samples": int(waveform.numel()),
        "hubert_frames": int(lengths[0]),
        "hubert_feature_shape": list(frames[0].shape),
        "speaker_shape": list(embedding.shape),
        "duration_shape": list(durations.shape),
        "duration_statistics_source": "synthetic_probe_only",
        "duration_mean": probe_duration_mean,
        "duration_std": probe_duration_std,
        "generated_shape": list(waveform_out.shape),
        "expected_generated_samples": int(
            expanded.shape[1] * GeneratorConfig().samples_per_frame
        ),
        "torch": torch.__version__,
        "hip": torch.version.hip,
        "device": str(device),
    }
    if report["generated_shape"][-1] != report["expected_generated_samples"]:
        raise RuntimeError(report)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
