"""Compute paired ASV EER with W-PRO or ECAPA embeddings."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch

from n019.audio import load_audio_16k_mono
from n019.metrics import equal_error_rate
from n019.models import extract_wpro_embedding, load_wpro
from n019.probe_eval_models import EncoderClassifier


def read_manifest(path: str) -> list[dict]:
    with open(path, encoding="utf-8") as handle:
        return [json.loads(line) for line in handle]


def embed_wpro(rows, model, device):
    output = []
    with torch.inference_mode():
        for row in rows:
            waveform = load_audio_16k_mono(row["audio"]).to(device)
            output.append(extract_wpro_embedding(model, waveform)[0].float().cpu())
    return torch.stack(output)


def embed_ecapa(rows, model, device):
    output = []
    with torch.inference_mode():
        for row in rows:
            waveform = load_audio_16k_mono(row["audio"]).unsqueeze(0).to(device)
            embedding = model.encode_batch(waveform).squeeze().float().cpu()
            output.append(torch.nn.functional.normalize(embedding, dim=0))
    return torch.stack(output)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--enroll", required=True)
    parser.add_argument("--trial", required=True)
    parser.add_argument("--embedding", choices=["wpro", "ecapa"], required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--device", default="cuda")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    enroll_rows = read_manifest(args.enroll)
    trial_rows = read_manifest(args.trial)
    if len(enroll_rows) != len(trial_rows):
        raise ValueError("enroll and trial manifests must be aligned")
    device = torch.device(args.device)
    model_root = Path.home() / "voice_projects/models/n019"
    if args.embedding == "wpro":
        model = load_wpro(model_root / "wpro", device)
        enroll = embed_wpro(enroll_rows, model, device)
        trial = embed_wpro(trial_rows, model, device)
    else:
        model = EncoderClassifier.from_hparams(
            source=str(model_root / "ecapa"),
            savedir=str(model_root / "ecapa"),
            overrides={"pretrained_path": str(model_root / "ecapa")},
            run_opts={"device": str(device)},
        )
        enroll = embed_ecapa(enroll_rows, model, device)
        trial = embed_ecapa(trial_rows, model, device)

    scores = torch.sum(enroll * trial, dim=1).numpy()
    enroll_speakers = np.array([row["speaker"] for row in enroll_rows])
    trial_speakers = np.array([row["speaker"] for row in trial_rows])
    labels = (enroll_speakers == trial_speakers).astype(np.int64)
    result = equal_error_rate(labels, scores)
    result.update(
        {
            "embedding": args.embedding,
            "enroll_manifest": args.enroll,
            "trial_manifest": args.trial,
        }
    )
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
