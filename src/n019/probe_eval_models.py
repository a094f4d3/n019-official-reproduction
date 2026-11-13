"""CPU checks for the ECAPA and ASR evaluation checkpoints."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor

from n019.audio import load_audio_16k_mono

try:
    from speechbrain.inference.classifiers import EncoderClassifier
except ModuleNotFoundError:
    from speechbrain.pretrained import EncoderClassifier


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", required=True)
    parser.add_argument("--out", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    model_root = Path.home() / "voice_projects/models/n019"
    waveform = load_audio_16k_mono(args.audio).unsqueeze(0)

    ecapa = EncoderClassifier.from_hparams(
        source=str(model_root / "ecapa"),
        savedir=str(model_root / "ecapa"),
        overrides={"pretrained_path": str(model_root / "ecapa")},
        run_opts={"device": "cpu"},
    )
    with torch.inference_mode():
        ecapa_embedding = ecapa.encode_batch(waveform).squeeze()

    processor = Wav2Vec2Processor.from_pretrained(
        str(model_root / "asr"),
        local_files_only=True,
    )
    asr = Wav2Vec2ForCTC.from_pretrained(
        str(model_root / "asr"),
        local_files_only=True,
    ).eval()
    inputs = processor(
        waveform.squeeze(0).numpy(),
        sampling_rate=16_000,
        return_tensors="pt",
    )
    with torch.inference_mode():
        logits = asr(inputs.input_values).logits
    token_ids = torch.argmax(logits, dim=-1)
    transcript = processor.batch_decode(token_ids)[0]

    report = {
        "ecapa_shape": list(ecapa_embedding.shape),
        "ecapa_norm": float(torch.linalg.vector_norm(ecapa_embedding)),
        "asr_logits_shape": list(logits.shape),
        "asr_transcript": transcript,
    }
    if report["ecapa_shape"] != [192]:
        raise RuntimeError(f"Unexpected ECAPA shape: {report['ecapa_shape']}")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
