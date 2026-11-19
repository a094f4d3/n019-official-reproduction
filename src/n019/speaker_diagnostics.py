"""Measure whether anonymized audio moves toward its assigned target speaker."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch

from n019.audio import load_audio_16k_mono
from n019.models import extract_wpro_embedding, load_wpro


def read_jsonl(path: str) -> list[dict]:
    with open(path, encoding="utf-8") as handle:
        return [json.loads(line) for line in handle]


def embed(rows, model, device):
    output = []
    with torch.inference_mode():
        for row in rows:
            waveform = load_audio_16k_mono(row["audio"]).to(device)
            vector = extract_wpro_embedding(model, waveform)[0].float().cpu()
            output.append(torch.nn.functional.normalize(vector, dim=0))
    return torch.stack(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--anon", required=True)
    parser.add_argument("--target-embeddings", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument(
        "--model",
        default=str(Path.home() / "voice_projects/models/n019/wpro"),
    )
    parser.add_argument("--device", default="cuda")
    args = parser.parse_args()
    device = torch.device(args.device)
    source_rows = read_jsonl(args.source)
    anon_rows = read_jsonl(args.anon)
    if len(source_rows) != len(anon_rows):
        raise ValueError("source and anonymized manifests must be aligned")
    targets = np.load(args.target_embeddings)
    model = load_wpro(
        Path(args.model),
        device,
    )
    source_vectors = embed(source_rows, model, device)
    anon_vectors = embed(anon_rows, model, device)
    target_vectors = torch.stack(
        [
            torch.from_numpy(targets[row["target_speaker"]].astype(np.float32))
            for row in anon_rows
        ]
    )
    source_scores = torch.sum(anon_vectors * source_vectors, dim=1)
    target_scores = torch.sum(anon_vectors * target_vectors, dim=1)
    margin = target_scores - source_scores
    result = {
        "utterances": len(anon_rows),
        "anon_to_source_mean": float(source_scores.mean()),
        "anon_to_target_mean": float(target_scores.mean()),
        "margin_target_minus_source_mean": float(margin.mean()),
        "margin_target_minus_source_median": float(margin.median()),
        "closer_to_target_fraction": float((margin > 0).float().mean()),
        "per_utterance": [
            {
                "audio": row["audio"],
                "speaker": row["speaker"],
                "target_speaker": row["target_speaker"],
                "source_score": float(source_scores[index]),
                "target_score": float(target_scores[index]),
                "margin": float(margin[index]),
            }
            for index, row in enumerate(anon_rows)
        ],
    }
    output = Path(args.out)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({key: value for key, value in result.items() if key != "per_utterance"}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
