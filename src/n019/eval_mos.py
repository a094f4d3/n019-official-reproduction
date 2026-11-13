"""Batch official UTMOS22 and WhiSQA scoring over Kaldi wav.scp inputs."""

from __future__ import annotations

import argparse
import contextlib
import csv
import functools
import hashlib
import importlib.util
import json
import os
import statistics
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import torch


NUM_THREADS = int(os.environ.get("N019_NUM_THREADS", "0"))
if NUM_THREADS > 0:
    torch.set_num_threads(NUM_THREADS)


@dataclass(frozen=True)
class AudioItem:
    utterance_id: str
    path: Path
    source_scp: Path


def sha256_file(path: str | Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_kaldi_map(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    with path.open(encoding="utf-8") as handle:
        for line_number, raw in enumerate(handle, 1):
            fields = raw.strip().split(maxsplit=1)
            if len(fields) != 2:
                raise ValueError(f"Invalid Kaldi entry at {path}:{line_number}")
            identifier, value = fields
            if identifier in result:
                raise ValueError(f"Duplicate key {identifier} in {path}")
            result[identifier] = value
    if not result:
        raise ValueError(f"Empty Kaldi map: {path}")
    return result


def resolve_audio(
    *,
    scp_path: Path,
    value: str,
    vpc_data_root: Path | None,
) -> Path:
    value = value.strip()
    if value.endswith("|"):
        raise ValueError(
            f"MOS scoring requires materialised WAV paths, not a pipe command: "
            f"{scp_path}: {value}"
        )
    raw = Path(value)
    candidates = [raw] if raw.is_absolute() else []
    candidates.append(scp_path.parent / raw)
    if vpc_data_root is not None:
        candidates.append(vpc_data_root / raw)
        candidates.append(vpc_data_root.parent / raw)
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    raise FileNotFoundError(
        f"Cannot resolve audio {value!r} from {scp_path}; "
        f"tried {[str(path) for path in candidates]}"
    )


def collect_audio_items(
    scp_paths: list[Path],
    *,
    vpc_data_root: Path | None,
) -> list[AudioItem]:
    if not scp_paths:
        raise ValueError("At least one --wav-scp is required")
    by_utterance: dict[str, AudioItem] = {}
    for raw_path in scp_paths:
        scp_path = raw_path.resolve()
        for identifier, value in read_kaldi_map(scp_path).items():
            path = resolve_audio(
                scp_path=scp_path,
                value=value,
                vpc_data_root=vpc_data_root,
            )
            item = AudioItem(identifier, path, scp_path)
            previous = by_utterance.get(identifier)
            if previous is None:
                by_utterance[identifier] = item
            elif previous.path != item.path:
                raise ValueError(
                    f"Conflicting paths for {identifier}: "
                    f"{previous.path} != {item.path}"
                )
    if not by_utterance:
        raise ValueError("No audio entries were collected")
    return [by_utterance[key] for key in sorted(by_utterance)]


def summarize_scores(
    records: list[dict],
    *,
    metric: str,
    backend: str,
    model_path: Path,
    code_source: Path,
    input_sha256: dict[str, str],
) -> dict:
    if not records:
        raise ValueError("No MOS records to summarise")
    values = [float(record["score"]) for record in records]
    return {
        "metric": metric,
        "backend": backend,
        "count": len(values),
        "mean": statistics.fmean(values),
        "stddev": statistics.stdev(values) if len(values) > 1 else 0.0,
        "min": min(values),
        "max": max(values),
        "model_path": str(model_path.resolve()),
        "model_sha256": sha256_file(model_path),
        "code_source": str(code_source.resolve()),
        "code_sha256": {
            str(path.relative_to(code_source)): sha256_file(path)
            for path in sorted(code_source.rglob("*.py"))
        },
        "input_sha256": input_sha256,
        "records": records,
    }


def _load_module(module_name: str, source: Path):
    spec = importlib.util.spec_from_file_location(module_name, source)
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot import {source}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@contextlib.contextmanager
def _trusted_torch_load_default():
    """Allow the pinned public checkpoints that predate weights_only=True."""

    original = torch.load

    def trusted_load(*args, **kwargs):
        kwargs.setdefault("weights_only", False)
        return original(*args, **kwargs)

    torch.load = trusted_load
    try:
        yield
    finally:
        torch.load = original


@contextlib.contextmanager
def _torchaudio_resample_dtype_compat():
    """Drop the removed dtype argument while constructing author code."""

    import torchaudio

    original = torchaudio.transforms.Resample

    class CompatResample(original):
        def __init__(self, *args, **kwargs):
            kwargs.pop("dtype", None)
            super().__init__(*args, **kwargs)

    torchaudio.transforms.Resample = CompatResample
    try:
        yield
    finally:
        torchaudio.transforms.Resample = original


def build_utmos_scorer(
    *,
    code_source: Path,
    checkpoint: Path,
    device: torch.device,
) -> Callable[[Path], float]:
    score_path = code_source / "score.py"
    if not score_path.is_file():
        raise FileNotFoundError(score_path)
    if not checkpoint.is_file():
        raise FileNotFoundError(checkpoint)
    sys.path.insert(0, str(code_source.resolve()))
    module = _load_module("n019_utmos_demo_score", score_path)
    previous_cwd = Path.cwd()
    try:
        # The author demo hard-codes wav2vec_small.pt as a relative path.
        os.chdir(checkpoint.parent)
        with _trusted_torch_load_default(), _torchaudio_resample_dtype_compat():
            scorer = module.Score(
                ckpt_path=str(checkpoint),
                input_sample_rate=16_000,
                device=device,
            )
    finally:
        os.chdir(previous_cwd)

    def score_file(path: Path) -> float:
        import torchaudio

        waveform, sample_rate = torchaudio.load(str(path))
        if sample_rate != 16_000:
            raise ValueError(
                f"UTMOS input must be 16 kHz, got {sample_rate}: {path}"
            )
        if waveform.shape[0] != 1:
            raise ValueError(f"UTMOS input must be mono: {path}")
        value = scorer.score(waveform.to(device))
        return float(value[0])

    return score_file


def build_whisqa_scorer(
    *,
    code_source: Path,
    checkpoint: Path,
    device: torch.device,
) -> Callable[[Path], float]:
    print(f"whisqa_build=start device={device}", flush=True)
    if not code_source.is_dir():
        raise FileNotFoundError(code_source)
    if not checkpoint.is_file():
        raise FileNotFoundError(checkpoint)
    sys.path.insert(0, str(code_source.resolve()))
    from models.whisper_ni_predictors import (  # type: ignore
        whisperMetricPredictorEncoderLayersTransformerSmall,
    )

    whisper_path = os.environ.get("N019_WHISPER_SMALL_PATH")
    if whisper_path:
        print(f"whisqa_build=patch_wrapper path={whisper_path}", flush=True)
        import models.whisper_ni_predictors as predictor_module

        wrapper = predictor_module.WhisperWrapper_encoder
        already_patched = (
            isinstance(wrapper, functools.partial)
            and (wrapper.keywords or {}).get("pretrained_model") == whisper_path
        )
        if not already_patched:
            predictor_module.WhisperWrapper_encoder = functools.partial(
                wrapper, pretrained_model=whisper_path
            )

    print("whisqa_build=construct", flush=True)
    model = whisperMetricPredictorEncoderLayersTransformerSmall()
    print("whisqa_build=load_checkpoint", flush=True)
    state = torch.load(checkpoint, map_location=device, weights_only=False)
    print("whisqa_build=load_state_dict", flush=True)
    model.load_state_dict(state)
    print(f"whisqa_build=move_model device={device}", flush=True)
    model.eval().to(device)
    print("whisqa_build=pin_wrapper_devices", flush=True)
    # Vendor wrappers choose CUDA whenever it is visible, even when the
    # evaluator explicitly requested CPU. Pin their internal input device so
    # model weights and waveform tensors stay colocated.
    for module in model.modules():
        if "device" in module.__dict__:
            module.device = device

    print("whisqa_build=complete", flush=True)
    previous_cwd = Path.cwd()

    def score_file(path: Path) -> float:
        import torchaudio

        waveform, sample_rate = torchaudio.load(str(path))
        if sample_rate != 16_000:
            raise ValueError(
                f"WhiSQA input must be 16 kHz, got {sample_rate}: {path}"
            )
        if waveform.shape[0] != 1:
            raise ValueError(f"WhiSQA input must be mono: {path}")
        try:
            # The author model loads models/mel_filters.npz by relative path.
            os.chdir(code_source)
            with torch.inference_mode():
                score = model(waveform.to(device))
        finally:
            os.chdir(previous_cwd)
        if score.numel() != 1:
            raise RuntimeError(
                f"WhiSQA returned {score.numel()} values instead of one"
            )
        # The official get_score.py prints score.item() * 5.
        return float(score.reshape(-1)[0]) * 5.0

    return score_file


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Batch-score official MOS predictors over Kaldi wav.scp files."
    )
    parser.add_argument("--backend", choices=["utmos", "whisqa"], required=True)
    parser.add_argument("--wav-scp", action="append", required=True)
    parser.add_argument("--vpc-data-root", default=None)
    parser.add_argument("--code-source", required=True)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--device", default="cuda")
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Smoke-test limit; zero scores every unique utterance.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.limit < 0:
        raise ValueError("--limit must be non-negative")
    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA/DCU requested but unavailable")
    device = torch.device(args.device)
    vpc_data_root = (
        Path(args.vpc_data_root).resolve()
        if args.vpc_data_root
        else None
    )
    items = collect_audio_items(
        [Path(path) for path in args.wav_scp],
        vpc_data_root=vpc_data_root,
    )
    if args.limit:
        items = items[: args.limit]
    code_source = Path(args.code_source).resolve()
    checkpoint = Path(args.checkpoint).resolve()
    if args.backend == "utmos":
        scorer = build_utmos_scorer(
            code_source=code_source,
            checkpoint=checkpoint,
            device=device,
        )
        metric = "UTMOS"
    else:
        scorer = build_whisqa_scorer(
            code_source=code_source,
            checkpoint=checkpoint,
            device=device,
        )
        metric = "WhiSQA"

    records = []
    for index, item in enumerate(items, 1):
        score = scorer(item.path)
        if not torch.isfinite(torch.tensor(score)):
            raise RuntimeError(
                f"{metric} produced a non-finite score for {item.utterance_id}"
            )
        records.append(
            {
                "id": item.utterance_id,
                "audio": str(item.path),
                "wav_scp": str(item.source_scp),
                "score": score,
            }
        )
        if index == 1 or index % 25 == 0 or index == len(items):
            print(f"{args.backend}_scored={index}/{len(items)}", flush=True)

    input_sha256 = {
        str(path.resolve()): sha256_file(path)
        for path in sorted({item.source_scp for item in items})
    }
    summary = summarize_scores(
        records,
        metric=metric,
        backend=args.backend,
        model_path=checkpoint,
        code_source=code_source,
        input_sha256=input_sha256,
    )
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    with out.with_suffix(".tsv").open(
        "w", encoding="utf-8", newline=""
    ) as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["id", "audio", "wav_scp", "score"],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(records)
    printable = {
        key: value for key, value in summary.items() if key != "records"
    }
    print(json.dumps(printable, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
