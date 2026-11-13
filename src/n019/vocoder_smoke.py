"""One-step Unit HiFi-GAN discriminator/generator training smoke."""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import torch
import torch.nn.functional as F

from n019.hifigan import (
    MultiPeriodDiscriminator,
    MultiScaleDiscriminator,
    UnitSpeakerHiFiGAN,
    discriminator_loss,
    feature_matching_loss,
    generator_loss,
)
from n019.spectral import mel_spectrogram
from n019.vocoder import UnitVocoderConfig


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--batch-size", type=int, default=2)
    parser.add_argument("--frames", type=int, default=64)
    args = parser.parse_args()
    if not torch.cuda.is_available():
        raise RuntimeError("DCU unavailable")

    device = torch.device("cuda")
    config = UnitVocoderConfig(
        speaker_dim=250,
        segment_frames=args.frames,
        batch_size=args.batch_size,
    )
    generator = UnitSpeakerHiFiGAN(
        vocab_size=config.vocabulary_size,
        unit_embedding_dim=config.unit_embedding_dim,
        speaker_dim=config.speaker_dim,
        generator_config=config.generator,
        padding_idx=config.padding_unit_id,
    ).to(device)
    mpd = MultiPeriodDiscriminator().to(device)
    msd = MultiScaleDiscriminator().to(device)
    optim_g = torch.optim.AdamW(generator.parameters(), 2e-4, betas=(0.8, 0.99))
    optim_d = torch.optim.AdamW(
        list(mpd.parameters()) + list(msd.parameters()), 2e-4, betas=(0.8, 0.99)
    )

    codes = torch.randint(0, 200, (args.batch_size, args.frames), device=device)
    speaker = torch.randn(args.batch_size, 250, device=device)
    real = torch.randn(args.batch_size, 1, args.frames * 320, device=device).clamp(
        -1, 1
    )
    started = time.time()
    fake = generator(codes, speaker)
    real_period, generated_period, _, _ = mpd(real, fake.detach().float())
    real_scale, generated_scale, _, _ = msd(real, fake.detach().float())
    loss_d = discriminator_loss(real_period, generated_period) + discriminator_loss(
        real_scale,
        generated_scale,
    )
    optim_d.zero_grad(set_to_none=True)
    loss_d.backward()
    optim_d.step()

    fake = generator(codes, speaker)
    real_period, generated_period, feature_real_period, feature_gen_period = mpd(
        real,
        fake.float(),
    )
    real_scale, generated_scale, feature_real_scale, feature_gen_scale = msd(
        real,
        fake.float(),
    )
    mel_loss = F.l1_loss(
        mel_spectrogram(real.squeeze(1)),
        mel_spectrogram(fake.squeeze(1).float()),
    )
    loss_g = (
        generator_loss(generated_period)
        + generator_loss(generated_scale)
        + feature_matching_loss(feature_real_period, feature_gen_period)
        + feature_matching_loss(feature_real_scale, feature_gen_scale)
        + config.mel_loss_weight * mel_loss
    )
    optim_g.zero_grad(set_to_none=True)
    loss_g.backward()
    optim_g.step()
    elapsed = time.time() - started
    report = {
        "device": torch.cuda.get_device_name(0),
        "elapsed_seconds": elapsed,
        "codes_shape": list(codes.shape),
        "waveform_shape": list(fake.shape),
        "loss_d": float(loss_d.detach()),
        "loss_g": float(loss_g.detach()),
        "mel_l1": float(mel_loss.detach()),
        "finite": bool(
            torch.isfinite(loss_d).all() and torch.isfinite(loss_g).all()
        ),
    }
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    torch.save({"generator": generator.state_dict()}, out / "generator.pt")
    (out / "metrics.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
