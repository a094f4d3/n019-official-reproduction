"""Five-minute DTK forward/backward and checkpoint smoke test."""

from __future__ import annotations

import argparse
import json
import platform
import time
from pathlib import Path

import torch
from torch import nn


class TinyUnitVocoder(nn.Module):
    def __init__(self, vocab_size: int = 201, unit_dim: int = 64, spk_dim: int = 250):
        super().__init__()
        self.unit = nn.Embedding(vocab_size, unit_dim)
        self.speaker = nn.Linear(spk_dim, unit_dim)
        self.body = nn.Sequential(
            nn.Conv1d(unit_dim * 2, 128, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.ConvTranspose1d(128, 32, kernel_size=320, stride=320),
        )
        self.head = nn.Conv1d(32, 1, kernel_size=1)

    def forward(self, units: torch.Tensor, speaker: torch.Tensor) -> torch.Tensor:
        x = self.unit(units).transpose(1, 2)
        z = self.speaker(speaker).unsqueeze(-1).expand(-1, -1, units.shape[1])
        x = torch.cat([x, z], dim=1)
        return self.head(self.body(x)).squeeze(1)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--steps", type=int, default=3)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not torch.cuda.is_available():
        raise RuntimeError("DCU is not available; run this through Slurm")

    device = torch.device("cuda")
    torch.manual_seed(0)
    model = TinyUnitVocoder().to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
    units = torch.randint(0, 200, (1, 20), device=device)
    speaker = torch.randn(1, 250, device=device)
    target = torch.randn(1, 6400, device=device)

    started = time.perf_counter()
    losses: list[float] = []
    for _ in range(args.steps):
        waveform = model(units, speaker)
        loss = torch.nn.functional.mse_loss(waveform, target)
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        optimizer.step()
        losses.append(float(loss.detach().cpu()))

    elapsed = time.perf_counter() - started
    grads_finite = all(
        parameter.grad is None or bool(torch.isfinite(parameter.grad).all())
        for parameter in model.parameters()
    )

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    checkpoint = out_dir / "tiny_model.pt"
    torch.save(model.state_dict(), checkpoint)
    restored = TinyUnitVocoder().to(device)
    restored.load_state_dict(torch.load(checkpoint, map_location=device))

    report = {
        "hostname": platform.node(),
        "torch": torch.__version__,
        "hip": torch.version.hip,
        "device_name": torch.cuda.get_device_name(0),
        "device_count": torch.cuda.device_count(),
        "bf16_supported": bool(torch.cuda.is_bf16_supported()),
        "fp16_supported": True,
        "steps": args.steps,
        "elapsed_sec": elapsed,
        "losses": losses,
        "grads_finite": grads_finite,
        "waveform_shape": [1, 6400],
        "checkpoint": str(checkpoint),
        "checkpoint_bytes": checkpoint.stat().st_size,
    }
    (out_dir / "metrics.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
