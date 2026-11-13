"""Evaluate wav2vec2 CTC WER on a JSONL manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor

from n019.audio import load_audio_16k_mono
from n019.metrics import corpus_wer


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--device", default="cuda")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument(
        "--model",
        default=str(
            Path.home()
            / "voice_projects/models/n019_official/vpc/exp/asr_n019_local"
        ),
    )
    args = parser.parse_args()
    device = torch.device(args.device)
    root = Path(args.model)
    processor = Wav2Vec2Processor.from_pretrained(str(root), local_files_only=True)
    model = Wav2Vec2ForCTC.from_pretrained(
        str(root), local_files_only=True
    ).to(device).eval()

    references = []
    hypotheses = []
    details = []
    with open(args.manifest, encoding="utf-8") as handle:
        rows = [json.loads(line) for line in handle]
    if args.limit:
        rows = rows[: args.limit]
    with torch.inference_mode():
        for index, row in enumerate(rows):
            waveform = load_audio_16k_mono(row["audio"]).numpy()
            inputs = processor(
                waveform,
                sampling_rate=16_000,
                return_tensors="pt",
            )
            logits = model(inputs.input_values.to(device)).logits
            hypothesis = processor.batch_decode(torch.argmax(logits, dim=-1))[0]
            references.append(row["text"])
            hypotheses.append(hypothesis)
            details.append(
                {
                    "audio": row["audio"],
                    "reference": row["text"],
                    "hypothesis": hypothesis,
                }
            )
            if index % 20 == 0:
                print(f"decoded={index + 1}/{len(rows)}")

    result = corpus_wer(references, hypotheses)
    result["details"] = details
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({key: value for key, value in result.items() if key != "details"}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
