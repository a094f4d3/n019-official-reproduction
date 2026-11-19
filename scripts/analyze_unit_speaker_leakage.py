#!/usr/bin/env python3
"""Compare speaker leakage in HuBERT units across layers.

The screen holds utterances and speakers fixed, fits a separate K=200
codebook for each layer, and measures how well normalized unit-count
histograms predict the source speaker. Lower speaker accuracy means the
unit representation retains less timbre information.
"""

from __future__ import annotations

import argparse
import json
import random
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
import torch
from sklearn.cluster import MiniBatchKMeans
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.feature_extraction.text import TfidfVectorizer

from n019.audio import load_audio_16k
from n019.manifest import iter_jsonl, speaker_id, utterance_id, write_json
from n019.units import feature_output_length


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--hubert-model", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--layers", default="6,9")
    parser.add_argument("--speakers", type=int, default=80)
    parser.add_argument("--utterances-per-speaker", type=int, default=8)
    parser.add_argument("--train-per-speaker", type=int, default=5)
    parser.add_argument("--k", type=int, default=200)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--seed", type=int, default=20261116)
    parser.add_argument("--device", default="cuda")
    return parser.parse_args()


def select_rows(
    rows: list[dict],
    *,
    speakers: int,
    utterances_per_speaker: int,
    train_per_speaker: int,
    seed: int,
) -> tuple[list[dict], list[dict]]:
    grouped: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        grouped[speaker_id(row)].append(row)
    eligible = [
        key
        for key, values in grouped.items()
        if len(values) >= utterances_per_speaker
    ]
    rng = random.Random(seed)
    rng.shuffle(eligible)
    selected_speakers = sorted(
        eligible[: min(speakers, len(eligible))]
    )
    if not selected_speakers:
        raise ValueError("No speakers have enough utterances")
    train: list[dict] = []
    test: list[dict] = []
    for key in selected_speakers:
        values = sorted(grouped[key], key=utterance_id)
        rng.shuffle(values)
        chosen = values[:utterances_per_speaker]
        train.extend(chosen[:train_per_speaker])
        test.extend(chosen[train_per_speaker:])
    rng.shuffle(train)
    rng.shuffle(test)
    return train, test


def normalized_histogram(tokens: list[int], k: int) -> np.ndarray:
    counts = Counter(tokens)
    result = np.zeros(k, dtype=np.float64)
    for token, count in counts.items():
        if token < 0 or token >= k:
            raise ValueError(f"Token outside [0, {k}): {token}")
        result[token] = count
    total = result.sum()
    if total <= 0:
        raise ValueError("Unit sequence is empty")
    return result / total


def pooled_speaker_vector(frames: torch.Tensor) -> np.ndarray:
    if frames.ndim != 2 or frames.shape[0] == 0:
        raise ValueError("Expected non-empty [frames, dim] features")
    mean = frames.mean(dim=0)
    std = frames.std(dim=0, unbiased=False)
    return torch.cat([mean, std]).numpy().astype(np.float64)


def classifier_metrics(
    train_x: list[np.ndarray],
    train_y: list[str],
    test_x: list[np.ndarray],
    test_y: list[str],
) -> dict[str, float | int]:
    model = make_pipeline(
        StandardScaler(),
        LogisticRegression(
            max_iter=2000,
            class_weight="balanced",
            random_state=0,
        ),
    )
    model.fit(np.stack(train_x), np.array(train_y))
    prediction = model.predict(np.stack(test_x))
    return {
        "train_utterances": len(train_y),
        "test_utterances": len(test_y),
        "speakers": len(set(train_y) | set(test_y)),
        "accuracy": float(accuracy_score(test_y, prediction)),
        "macro_f1": float(
            f1_score(test_y, prediction, average="macro", zero_division=0)
        ),
        "chance_accuracy": 1.0 / len(set(train_y) | set(test_y)),
    }


def sequence_ngram_text(tokens: list[int]) -> str:
    """Encode a unit sequence so temporal n-grams can be classified."""
    if not tokens:
        raise ValueError("Unit sequence is empty")
    return " ".join(f"u{token}" for token in tokens)


def sequence_ngram_metrics(
    train_tokens: list[list[int]],
    train_y: list[str],
    test_tokens: list[list[int]],
    test_y: list[str],
) -> dict[str, float | int]:
    vectorizer = TfidfVectorizer(
        analyzer="word",
        token_pattern=r"\S+",
        ngram_range=(1, 3),
        min_df=2,
        max_features=200_000,
        sublinear_tf=True,
    )
    train_x = vectorizer.fit_transform(
        [sequence_ngram_text(tokens) for tokens in train_tokens]
    )
    test_x = vectorizer.transform(
        [sequence_ngram_text(tokens) for tokens in test_tokens]
    )
    model = LogisticRegression(
        max_iter=2000,
        class_weight="balanced",
        random_state=0,
    )
    model.fit(train_x, np.array(train_y))
    prediction = model.predict(test_x)
    return {
        "train_utterances": len(train_y),
        "test_utterances": len(test_y),
        "speakers": len(set(train_y) | set(test_y)),
        "accuracy": float(accuracy_score(test_y, prediction)),
        "macro_f1": float(
            f1_score(test_y, prediction, average="macro", zero_division=0)
        ),
        "chance_accuracy": 1.0 / len(set(train_y) | set(test_y)),
        "ngram_min": 1,
        "ngram_max": 3,
        "features": int(train_x.shape[1]),
    }


def extract_layer_features(
    rows: list[dict],
    *,
    model_dir: Path,
    layers: list[int],
    batch_size: int,
    device: torch.device,
) -> dict[int, list[torch.Tensor]]:
    from transformers import AutoFeatureExtractor, HubertModel

    feature_extractor = AutoFeatureExtractor.from_pretrained(
        str(model_dir),
        local_files_only=True,
    )
    model = HubertModel.from_pretrained(
        str(model_dir),
        local_files_only=True,
    ).to(device).eval()
    output: dict[int, list[torch.Tensor]] = {layer: [] for layer in layers}
    with torch.inference_mode():
        for start in range(0, len(rows), batch_size):
            batch = rows[start : start + batch_size]
            waveforms = [load_audio_16k(row["audio"]) for row in batch]
            processed = feature_extractor(
                [waveform.numpy() for waveform in waveforms],
                sampling_rate=16_000,
                return_tensors="pt",
                padding=True,
                return_attention_mask=True,
            )
            input_values = processed["input_values"].to(device)
            attention_mask = processed["attention_mask"].to(device)
            hidden_states = model(
                input_values=input_values,
                attention_mask=attention_mask,
                output_hidden_states=True,
                return_dict=True,
            ).hidden_states
            input_lengths = attention_mask.sum(dim=1).long().cpu().tolist()
            lengths = [
                feature_output_length(
                    int(length),
                    model.config.conv_stride,
                    model.config.conv_kernel,
                )
                for length in input_lengths
            ]
            for layer in layers:
                hidden = hidden_states[layer]
                for index, length in enumerate(lengths):
                    if length <= 0:
                        raise ValueError(
                            f"Utterance {utterance_id(batch[index])} "
                            f"is too short for HuBERT"
                        )
                    output[layer].append(
                        hidden[index, :length].float().cpu()
                    )
            print(
                f"extracted={min(start + len(batch), len(rows))}/{len(rows)}",
                flush=True,
            )
    return output


def main() -> int:
    args = parse_args()
    layers = [int(item) for item in args.layers.split(",") if item]
    if not layers:
        raise ValueError("--layers must not be empty")
    if args.train_per_speaker >= args.utterances_per_speaker:
        raise ValueError("train-per-speaker must be smaller than the total")
    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA/DCU requested but unavailable")
    device = torch.device(args.device)
    rows = list(iter_jsonl(args.manifest))
    train_rows, test_rows = select_rows(
        rows,
        speakers=args.speakers,
        utterances_per_speaker=args.utterances_per_speaker,
        train_per_speaker=args.train_per_speaker,
        seed=args.seed,
    )
    all_rows = train_rows + test_rows
    print(
        f"selected train={len(train_rows)} test={len(test_rows)} "
        f"speakers={len({speaker_id(row) for row in all_rows})}",
        flush=True,
    )
    features = extract_layer_features(
        all_rows,
        model_dir=Path(args.hubert_model),
        layers=layers,
        batch_size=args.batch_size,
        device=device,
    )
    split = len(train_rows)
    train_y = [speaker_id(row) for row in train_rows]
    test_y = [speaker_id(row) for row in test_rows]
    result: dict[str, object] = {
        "manifest": str(Path(args.manifest).resolve()),
        "hubert_model": str(Path(args.hubert_model).resolve()),
        "layers": layers,
        "k": args.k,
        "seed": args.seed,
        "train_utterances": len(train_rows),
        "test_utterances": len(test_rows),
        "speakers": len(set(train_y) | set(test_y)),
        "results": {},
    }
    for layer in layers:
        layer_features = features[layer]
        train_frames = torch.cat(layer_features[:split], dim=0).numpy()
        kmeans = MiniBatchKMeans(
            n_clusters=args.k,
            random_state=args.seed,
            batch_size=4096,
            n_init=3,
            max_iter=100,
            tol=1e-4,
        )
        kmeans.fit(train_frames)
        tokens = [
            kmeans.predict(value.numpy()).astype(np.int64).tolist()
            for value in layer_features
        ]
        histograms = [
            normalized_histogram(value, args.k) for value in tokens
        ]
        unit_metrics = classifier_metrics(
            histograms[:split],
            train_y,
            histograms[split:],
            test_y,
        )
        ngram_metrics = sequence_ngram_metrics(
            tokens[:split],
            train_y,
            tokens[split:],
            test_y,
        )
        raw_vectors = [
            pooled_speaker_vector(value) for value in layer_features
        ]
        raw_metrics = classifier_metrics(
            raw_vectors[:split],
            train_y,
            raw_vectors[split:],
            test_y,
        )
        unit_metrics["inertia"] = float(kmeans.inertia_)
        unit_metrics["relative_to_raw"] = (
            unit_metrics["accuracy"] / raw_metrics["accuracy"]
        )
        result["results"][str(layer)] = {
            "unit_histogram": unit_metrics,
            "unit_sequence_ngram": ngram_metrics,
            "raw_mean_std": raw_metrics,
        }
        print(
            json.dumps(
                {"layer": layer, **result["results"][str(layer)]},
                sort_keys=True,
            ),
            flush=True,
        )
    write_json(args.out, result)
    print(f"OUT={args.out}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
