"""Evaluate the VPC2024 wav2vec2 CTC model with native PyTorch tensors.

The official SpeechBrain EncoderASR path hangs after model loading on the
SCNet DCU driver. This module reconstructs the same model from the shipped
``wav2vec2.ckpt`` and ``asr.ckpt``, uses the official tokenizer labels, and
performs greedy CTC decoding without SpeechBrain's inference wrapper.
"""

from __future__ import annotations

import argparse
import ast
import json
import os
from pathlib import Path

import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset
from transformers import Wav2Vec2Config, Wav2Vec2FeatureExtractor, Wav2Vec2Model

from n019.audio import load_audio_16k_mono
from n019.metrics import corpus_wer


NUM_THREADS = int(os.environ.get("N019_NUM_THREADS", "0"))
if NUM_THREADS > 0:
    torch.set_num_threads(NUM_THREADS)


def load_labels(path: Path) -> dict[int, str]:
    labels: dict[int, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=>" not in line:
            continue
        left, right = line.rsplit("=>", 1)
        try:
            label = ast.literal_eval(left.strip())
            index = int(right.strip())
        except (ValueError, SyntaxError):
            continue
        if isinstance(label, str) and not label.startswith("<"):
            labels[index] = label
    if not labels:
        raise ValueError(f"No tokenizer labels found in {path}")
    return labels


class VpcCtcModel(nn.Module):
    def __init__(self, model_dir: Path, labels: dict[int, str]):
        super().__init__()
        self.backbone = Wav2Vec2Model(
            Wav2Vec2Config.from_pretrained(str(model_dir))
        )
        self.dnn = nn.Sequential(
            nn.Linear(1024, 1024),
            nn.LeakyReLU(),
            nn.Linear(1024, 1024),
            nn.LeakyReLU(),
        )
        self.ctc = nn.Linear(1024, max(labels) + 1)

    def forward(self, input_values, attention_mask=None):
        hidden = self.backbone(
            input_values=input_values,
            attention_mask=attention_mask,
        ).last_hidden_state
        return self.ctc(self.dnn(hidden))


class AudioDataset(Dataset):
    def __init__(self, wav_scp: Path, limit: int = 0, offset: int = 0):
        self.items = []
        for line in wav_scp.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            utt_id, audio = line.split(maxsplit=1)
            self.items.append((utt_id, Path(audio)))
        self.items = self.items[offset : offset + limit] if limit else self.items[offset:]

    def __len__(self):
        return len(self.items)

    def __getitem__(self, index):
        utt_id, audio = self.items[index]
        return utt_id, load_audio_16k_mono(audio).numpy()


def collate(batch):
    ids, waveforms = zip(*batch)
    return list(ids), list(waveforms)


def greedy_decode(token_ids: torch.Tensor, labels: dict[int, str]) -> str:
    pieces = []
    previous = None
    for value in token_ids.tolist():
        if value == previous:
            continue
        previous = value
        if value in (0, 1, 2):
            continue
        pieces.append(labels.get(value, ""))
    return "".join(pieces)


def load_vpc_model(model_dir: Path, device: torch.device):
    labels = load_labels(model_dir / "tokenizer.ckpt")
    model = VpcCtcModel(model_dir, labels)
    backbone = torch.load(
        model_dir / "wav2vec2.ckpt",
        map_location="cpu",
        weights_only=False,
    )
    backbone = {
        key.removeprefix("model."): value
        for key, value in backbone.items()
    }
    missing, unexpected = model.backbone.load_state_dict(
        backbone,
        strict=False,
    )
    if unexpected:
        raise RuntimeError(f"Unexpected backbone keys: {unexpected[:5]}")
    if missing:
        raise RuntimeError(f"Missing backbone keys: {missing[:5]}")

    head = torch.load(
        model_dir / "asr.ckpt",
        map_location="cpu",
        weights_only=False,
    )
    state = {
        "dnn.0.weight": head["0.linear.w.weight"],
        "dnn.0.bias": head["0.linear.w.bias"],
        "dnn.2.weight": head["0.linear_0.w.weight"],
        "dnn.2.bias": head["0.linear_0.w.bias"],
        "ctc.weight": head["1.w.weight"],
        "ctc.bias": head["1.w.bias"],
    }
    model.load_state_dict(state, strict=False)
    return model.to(device).eval(), labels


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vpc-data-root", required=True)
    parser.add_argument("--dataset", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--device", default="cuda")
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--expected-count", type=int, default=1496)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--offset", type=int, default=0)
    args = parser.parse_args()

    dataset_root = Path(args.vpc_data_root) / args.dataset
    wav_scp = dataset_root / "wav.scp"
    text_path = dataset_root / "text"
    if not wav_scp.is_file() or not text_path.is_file():
        raise FileNotFoundError(f"Missing VPC dataset files in {dataset_root}")

    device = torch.device(args.device)
    model_dir = Path(args.model).resolve()
    model, labels = load_vpc_model(model_dir, device)
    feature_extractor = Wav2Vec2FeatureExtractor.from_pretrained(
        str(model_dir),
        local_files_only=True,
    )
    dataset = AudioDataset(
        wav_scp,
        limit=args.limit,
        offset=args.offset,
    )
    references = {}
    for line in text_path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            utt_id, text = line.split(maxsplit=1)
            references[utt_id] = text
    selected_ids = {utt_id for utt_id, _ in dataset.items}
    references = {
        utt_id: references[utt_id]
        for utt_id in selected_ids
        if utt_id in references
    }

    loader = DataLoader(
        dataset,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=0,
        collate_fn=collate,
    )
    hypotheses = {}
    with torch.inference_mode():
        for ids, waveforms in loader:
            processed = feature_extractor(
                waveforms,
                sampling_rate=16_000,
                return_tensors="pt",
                return_attention_mask=True,
                padding=True,
            )
            logits = model(
                processed.input_values.to(device),
                processed.attention_mask.to(device),
            )
            for utt_id, token_ids in zip(ids, logits.argmax(dim=-1)):
                hypotheses[utt_id] = greedy_decode(token_ids, labels)
            print(f"decoded={len(hypotheses)}/{len(dataset)}", flush=True)

    expected = args.limit or args.expected_count
    if len(hypotheses) != expected or len(references) != expected:
        raise RuntimeError(
            f"Expected {expected} references/hypotheses, "
            f"got {len(references)}/{len(hypotheses)}"
        )
    reference_list = [references[key] for key in hypotheses]
    hypothesis_list = [hypotheses[key] for key in hypotheses]
    result = corpus_wer(reference_list, hypothesis_list)
    result.update(
        {
            "backend": "vpc2024_wav2vec2_native_ctc",
            "dataset": args.dataset,
            "model": str(model_dir),
            "utterances": len(hypotheses),
            "references": len(references),
            "wer_percent": result["wer"] * 100.0,
            "hypotheses": str(Path(args.out).parent / "vpc_asr" / "text"),
        }
    )
    output = Path(args.out)
    output.parent.mkdir(parents=True, exist_ok=True)
    hypothesis_path = output.parent / "vpc_asr" / "text"
    hypothesis_path.parent.mkdir(parents=True, exist_ok=True)
    hypothesis_path.write_text(
        "\n".join(
            f"{utt_id} {hypotheses[utt_id]}"
            for utt_id in sorted(hypotheses)
        )
        + "\n",
        encoding="utf-8",
    )
    result["hypotheses"] = str(hypothesis_path)
    output.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
