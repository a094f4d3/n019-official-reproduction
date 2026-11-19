"""Run the complete N019 DU-X-Y anonymisation pipeline."""

from __future__ import annotations

import argparse
import math
import shutil
import time
from pathlib import Path

import numpy as np
import torch

from n019.audio import (
    PAD_UNIT_ID,
    SAMPLE_RATE,
    collapse_consecutive,
    expand_units,
    round_durations_with_residual,
    sanitize_predicted_durations,
    save_audio,
)
from n019.duration import load_duration_checkpoint
from n019.manifest import (
    append_jsonl,
    iter_jsonl,
    safe_filename,
    speaker_id,
    sha256_file,
    utterance_id,
    write_json,
    write_jsonl,
)
from n019.vocoder import load_generator


OUTPUT_METADATA_FILES = frozenset({"launch.txt", "stdout.log"})


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Anonymise with DU-X-Y: X in orig/pred/nt/ecapa, "
        "Y in nt/ecapa."
    )
    parser.add_argument("--source-manifest", required=True)
    parser.add_argument("--unit-records", required=True)
    parser.add_argument("--target-map", required=True)
    parser.add_argument("--vocoder", required=True)
    parser.add_argument("--vocoder-type", choices=["nt", "ecapa"], required=True)
    parser.add_argument("--vocoder-embeddings", required=True)
    parser.add_argument(
        "--target-embedding-key",
        choices=["target_id", "target_speaker"],
        default="target_id",
        help=(
            "Look up the vocoder target embedding by the mapped target "
            "utterance or by its target speaker. The paper does not publish "
            "the pooling rule; record this choice in run_meta.json."
        ),
    )
    parser.add_argument(
        "--target-embedding-mode",
        default="provided",
        help=(
            "Human-readable provenance, e.g. utterance or "
            "speaker_mean_l2. This does not alter tensor loading."
        ),
    )
    parser.add_argument(
        "--duration-mode",
        choices=["orig", "pred", "nt", "ecapa"],
        required=True,
    )
    parser.add_argument("--duration-model", default=None)
    parser.add_argument("--duration-embeddings", default=None)
    parser.add_argument(
        "--duration-embedding-key",
        choices=["target_id", "target_speaker"],
        default="target_id",
        help=(
            "Look up the duration-conditioning embedding by target utterance "
            "or target speaker. Speaker-level duration models should use "
            "target_speaker when a speaker-pooled embedding is available."
        ),
    )
    parser.add_argument("--out-dir", required=True)
    parser.add_argument(
        "--speaker-embedding-scale",
        type=float,
        default=1.0,
        help=(
            "Multiply the target speaker embedding before vocoder "
            "conditioning. The paper-faithful value is 1.0."
        ),
    )
    parser.add_argument(
        "--duration-extrapolation",
        type=float,
        default=0.0,
        help=(
            "Extrapolate predicted durations away from original durations by "
            "this factor. Zero is the paper-faithful prediction."
        ),
    )
    parser.add_argument(
        "--duration-preserve-total",
        action="store_true",
        help=(
            "After duration extrapolation, rescale to the original predicted "
            "total duration so only local rhythm is exaggerated."
        ),
    )
    parser.add_argument(
        "--duration-soft-cap-frames",
        type=float,
        default=0.0,
        help=(
            "Soft-limit each extrapolated unit-duration change to this many "
            "HuBERT frames before total-duration rescaling. Zero disables "
            "the cap."
        ),
    )
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--flush-every", type=int, default=25)
    parser.add_argument("--space-safety-factor", type=float, default=1.1)
    parser.add_argument("--skip-space-check", action="store_true")
    parser.add_argument("--device", default="cuda")
    return parser.parse_args()


class EmbeddingStore:
    def __init__(self, path: str | Path, *, expected_dim: int | None = None) -> None:
        archive = np.load(path, allow_pickle=False)
        self.values = {
            key: torch.from_numpy(archive[key].astype(np.float32))
            for key in archive.files
        }
        archive.close()
        if not self.values:
            raise ValueError(f"Embedding archive is empty: {path}")
        dimensions = {int(value.numel()) for value in self.values.values()}
        if len(dimensions) != 1:
            raise ValueError(f"Mixed embedding dimensions in {path}: {dimensions}")
        self.dimension = dimensions.pop()
        if expected_dim is not None and self.dimension != expected_dim:
            raise ValueError(
                f"{path} contains {self.dimension}-D embeddings, "
                f"expected {expected_dim}"
            )

    def get(self, key: str) -> torch.Tensor:
        if key not in self.values:
            raise KeyError(f"Embedding key not found: {key}")
        return self.values[key]


def estimate_pcm16_wav_bytes(seconds: float) -> int:
    if seconds < 0.0:
        raise ValueError("seconds must be non-negative")
    return int(math.ceil(seconds * SAMPLE_RATE * 2 + 44))


def require_free_space(*, required_bytes: int, available_bytes: int) -> None:
    if required_bytes < 0 or available_bytes < 0:
        raise ValueError("space values must be non-negative")
    if required_bytes > available_bytes:
        raise OSError(
            f"Insufficient output space: need {required_bytes} bytes, "
            f"available {available_bytes} bytes"
        )


def scale_speaker_embedding(
    embedding: torch.Tensor,
    scale: float,
) -> torch.Tensor:
    """Apply a finite positive conditioning-strength scale."""
    if not math.isfinite(scale):
        raise ValueError("speaker embedding scale must be finite")
    if scale <= 0.0:
        raise ValueError("speaker embedding scale must be positive")
    return embedding * float(scale)


def extrapolate_durations(
    predicted: torch.Tensor,
    original: torch.Tensor,
    strength: float,
    *,
    preserve_total: bool,
    soft_cap_frames: float = 0.0,
) -> tuple[torch.Tensor, int]:
    """Exaggerate the predicted rhythm while keeping durations positive."""
    if predicted.shape != original.shape:
        raise ValueError("Predicted and original duration shapes differ")
    if not math.isfinite(strength) or strength < 0.0:
        raise ValueError("duration extrapolation must be finite and non-negative")
    if not math.isfinite(soft_cap_frames) or soft_cap_frames < 0.0:
        raise ValueError("duration soft cap must be finite and non-negative")
    if strength == 0.0:
        return predicted, 0
    predicted_total = float(predicted.sum())
    delta = float(strength) * (predicted - original)
    if soft_cap_frames > 0.0:
        # Keep the sign of the distortion, but stop rare predictor outliers
        # from dominating the local rhythm.
        delta = float(soft_cap_frames) * torch.tanh(
            delta / float(soft_cap_frames)
        )
    adjusted = predicted + delta
    adjusted, negative = sanitize_predicted_durations(adjusted)
    if preserve_total:
        adjusted_total = float(adjusted.sum())
        if predicted_total <= 0.0 or adjusted_total <= 0.0:
            raise ValueError("Duration totals must be positive")
        adjusted = adjusted * (predicted_total / adjusted_total)
    return adjusted, negative


def ensure_output_dir_available(
    out_dir: Path,
    *,
    overwrite: bool,
    resume: bool,
) -> None:
    """Allow launcher metadata while rejecting an unrelated prior run."""
    if overwrite or resume or not out_dir.exists():
        return
    unexpected = [
        path.name
        for path in out_dir.iterdir()
        if path.name not in OUTPUT_METADATA_FILES
    ]
    if unexpected:
        raise FileExistsError(
            f"Output directory is not empty: {out_dir}; "
            "pass --overwrite for a new run or --resume to continue"
        )


def load_anonymize_resume(
    path: str | Path,
    *,
    source_ids: set[str],
    out_dir: str | Path,
    duration_mode: str,
    vocoder_type: str,
    target_embedding_key: str = "target_id",
    duration_embedding_key: str = "target_id",
    target_embedding_mode: str = "provided",
) -> list[dict]:
    """Validate completed rows from an interrupted anonymisation run."""
    rows = list(iter_jsonl(path))
    seen: set[str] = set()
    out_dir = Path(out_dir).resolve()
    for row in rows:
        identifier = utterance_id(row)
        if identifier in seen:
            raise ValueError(f"Duplicate anonymisation resume row: {identifier}")
        if identifier not in source_ids:
            raise ValueError(f"Resume row not in source manifest: {identifier}")
        if row.get("duration_mode") != duration_mode:
            raise ValueError(f"Duration mode mismatch for {identifier}")
        if row.get("vocoder_type") != vocoder_type:
            raise ValueError(f"Vocoder type mismatch for {identifier}")
        if (
            "target_embedding_key" in row
            and row["target_embedding_key"] != target_embedding_key
        ):
            raise ValueError(f"Target embedding key mismatch for {identifier}")
        if (
            "duration_embedding_key" in row
            and row["duration_embedding_key"] != duration_embedding_key
        ):
            raise ValueError(f"Duration embedding key mismatch for {identifier}")
        if (
            "target_embedding_mode" in row
            and row["target_embedding_mode"] != target_embedding_mode
        ):
            raise ValueError(f"Target embedding mode mismatch for {identifier}")
        expected = (out_dir / safe_filename(identifier, ".wav")).resolve()
        actual = Path(row["audio"]).resolve()
        if actual != expected:
            raise ValueError(
                f"Resume audio path mismatch for {identifier}: "
                f"{actual} != {expected}"
            )
        if not actual.is_file():
            raise FileNotFoundError(actual)
        seen.add(identifier)
    return rows


def main() -> int:
    args = parse_args()
    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA/DCU requested but unavailable")
    if args.flush_every <= 0:
        raise ValueError("--flush-every must be positive")
    if args.space_safety_factor < 1.0:
        raise ValueError("--space-safety-factor must be at least 1.0")
    if (
        not math.isfinite(args.duration_extrapolation)
        or args.duration_extrapolation < 0.0
    ):
        raise ValueError("--duration-extrapolation must be finite and non-negative")
    if (
        not math.isfinite(args.duration_soft_cap_frames)
        or args.duration_soft_cap_frames < 0.0
    ):
        raise ValueError(
            "--duration-soft-cap-frames must be finite and non-negative"
        )
    if args.duration_mode == "orig" and args.duration_extrapolation != 0.0:
        raise ValueError(
            "--duration-extrapolation requires a predicted duration mode"
        )
    scale_speaker_embedding(
        torch.empty(0),
        args.speaker_embedding_scale,
    )
    if args.duration_mode in {"pred", "nt", "ecapa"} and not args.duration_model:
        raise ValueError("--duration-model is required for predicted duration modes")
    if args.duration_mode in {"nt", "ecapa"} and not args.duration_embeddings:
        raise ValueError(
            "--duration-embeddings is required for conditioned duration modes"
        )
    device = torch.device(args.device)
    generator, generator_checkpoint = load_generator(args.vocoder, device)
    configured_vocoder_type = generator_checkpoint["config"].get("speaker_dim")
    expected_dim = 250 if args.vocoder_type == "nt" else 192
    if configured_vocoder_type != expected_dim:
        raise ValueError(
            f"Vocoder is configured for {configured_vocoder_type}-D speakers, "
            f"but --vocoder-type {args.vocoder_type} requires {expected_dim}-D"
        )
    duration_model = None
    duration_embeddings = None
    if args.duration_mode != "orig":
        duration_model, duration_checkpoint = load_duration_checkpoint(
            args.duration_model,
            device=device,
        )
        expected = 0 if args.duration_mode == "pred" else (
            250 if args.duration_mode == "nt" else 192
        )
        actual = duration_checkpoint["model_config"]["speaker_dim"]
        if actual != expected:
            raise ValueError(
                f"Duration model speaker_dim={actual}, expected {expected}"
            )
        trained_kind = duration_checkpoint.get("training_config", {}).get(
            "embedding_kind"
        )
        expected_duration_kind = (
            "none" if args.duration_mode == "pred" else args.duration_mode
        )
        if trained_kind and trained_kind != expected_duration_kind:
            raise ValueError(
                f"Duration model was trained with {trained_kind} embeddings, "
                f"but --duration-mode is {args.duration_mode}"
            )
        if args.duration_mode in {"nt", "ecapa"}:
            duration_embeddings = EmbeddingStore(
                args.duration_embeddings,
                expected_dim=expected,
            )
    vocoder_embeddings = EmbeddingStore(
        args.vocoder_embeddings,
        expected_dim=expected_dim,
    )
    sources = list(iter_jsonl(args.source_manifest))
    if not sources:
        raise ValueError("Source manifest is empty")
    source_ids = [utterance_id(row) for row in sources]
    if len(source_ids) != len(set(source_ids)):
        raise ValueError("Source manifest contains duplicate utterance IDs")
    unit_rows = list(iter_jsonl(args.unit_records))
    unit_records = {utterance_id(row): row for row in unit_rows}
    if len(unit_records) != len(unit_rows):
        raise ValueError("Unit record file contains duplicate utterance IDs")
    target_rows = list(iter_jsonl(args.target_map))
    target_map = {row["source_id"]: row for row in target_rows}
    if len(target_map) != len(target_rows):
        raise ValueError("Target map contains duplicate source IDs")
    out_dir = Path(args.out_dir)
    partial_path = out_dir / "anon.partial.jsonl"
    ensure_output_dir_available(
        out_dir,
        overwrite=args.overwrite,
        resume=args.resume,
    )
    resume_rows: list[dict] = []
    if args.resume:
        if not partial_path.is_file():
            raise FileNotFoundError(partial_path)
        resume_rows = load_anonymize_resume(
            partial_path,
            source_ids=set(source_ids),
            out_dir=out_dir,
            duration_mode=args.duration_mode,
            vocoder_type=args.vocoder_type,
            target_embedding_key=args.target_embedding_key,
            duration_embedding_key=args.duration_embedding_key,
            target_embedding_mode=args.target_embedding_mode,
        )
        completed_ids = {
            utterance_id(row) for row in resume_rows
        }
        sources = [
            row for row in sources if utterance_id(row) not in completed_ids
        ]
    elif partial_path.exists():
        raise FileExistsError(
            f"{partial_path} already exists; pass --resume to continue it"
        )
    if not args.skip_space_check:
        missing_seconds = [
            utterance_id(row)
            for row in sources
            if row.get("seconds") is None
        ]
        if missing_seconds:
            raise ValueError(
                "Source manifest is missing seconds for space estimation: "
                f"{missing_seconds[:5]}"
            )
        wav_bytes = sum(
            estimate_pcm16_wav_bytes(float(row["seconds"]))
            for row in sources
        )
        required_bytes = int(math.ceil(wav_bytes * args.space_safety_factor))
        space_root = out_dir if out_dir.exists() else out_dir.parent
        require_free_space(
            required_bytes=required_bytes,
            available_bytes=shutil.disk_usage(space_root).free,
        )
    out_dir.mkdir(parents=True, exist_ok=True)
    if not args.resume:
        write_jsonl(partial_path, [])
    output_rows = list(resume_rows)
    started = time.time()
    total = len(output_rows) + len(sources)
    negative_duration_values = sum(
        int(row.get("negative_duration_values", 0)) for row in resume_rows
    )
    pending: list[dict] = []
    with partial_path.open("a", encoding="utf-8") as partial_handle:
        with torch.inference_mode():
            for index, source in enumerate(sources):
                source_id = utterance_id(source)
                if source_id not in unit_records:
                    raise KeyError(f"No unit record for {source_id}")
                if source_id not in target_map:
                    raise KeyError(f"No target mapping for {source_id}")
                mapping = target_map[source_id]
                if mapping.get("source_speaker") != speaker_id(source):
                    raise ValueError(
                        f"Target map speaker mismatch for {source_id}: "
                        f"{mapping.get('source_speaker')} != {speaker_id(source)}"
                    )
                unit_row = unit_records[source_id]
                codes = torch.from_numpy(
                    np.load(unit_row["codes_path"]).astype(np.int64, copy=False)
                )
                if codes.numel() == 0:
                    raise ValueError(f"Empty code sequence for {source_id}")
                if int(codes.min()) < 0 or int(codes.max()) >= PAD_UNIT_ID:
                    raise ValueError(f"Invalid unit IDs for {source_id}")
                units, original_durations = collapse_consecutive(codes)
                target_vocoder_embedding = vocoder_embeddings.get(
                    mapping[args.target_embedding_key]
                ).unsqueeze(0).to(device)
                target_vocoder_embedding = scale_speaker_embedding(
                    target_vocoder_embedding,
                    args.speaker_embedding_scale,
                )
                negative = 0

                if args.duration_mode == "orig":
                    durations = original_durations
                else:
                    if args.duration_mode == "pred":
                        duration_speaker = None
                    else:
                        duration_speaker = duration_embeddings.get(
                            mapping[args.duration_embedding_key]
                        ).unsqueeze(0).to(device)
                    assert duration_model is not None
                    predicted = duration_model(
                        units.unsqueeze(0).to(device),
                        duration_speaker,
                    )[0].cpu()
                    predicted, negative = sanitize_predicted_durations(
                        predicted
                    )
                    if args.duration_extrapolation:
                        predicted, extra_negative = extrapolate_durations(
                            predicted,
                            original_durations.float(),
                            args.duration_extrapolation,
                            preserve_total=args.duration_preserve_total,
                            soft_cap_frames=args.duration_soft_cap_frames,
                        )
                        negative += extra_negative
                    if negative:
                        print(
                            f"negative_duration_values={negative} "
                            f"utterance={source_id}",
                            flush=True,
                        )
                    negative_duration_values += negative
                    durations = round_durations_with_residual(
                        predicted,
                        minimum_one=True,
                    )
                expanded = expand_units(units, durations).unsqueeze(0).to(device)
                waveform = generator(expanded, target_vocoder_embedding)[0, 0]
                output_path = out_dir / safe_filename(source_id, ".wav")
                save_audio(output_path, waveform.float().cpu())
                pending.append(
                    {
                        **source,
                        "id": source_id,
                        "source_audio": source["audio"],
                        "audio": str(output_path),
                        "target_id": mapping["target_id"],
                        "target_speaker": mapping["target_speaker"],
                        "target_embedding_key": args.target_embedding_key,
                        "target_embedding_mode": args.target_embedding_mode,
                        "duration_mode": args.duration_mode,
                        "duration_embedding_key": args.duration_embedding_key,
                        "vocoder_type": args.vocoder_type,
                        "speaker_embedding_scale": args.speaker_embedding_scale,
                        "duration_extrapolation": args.duration_extrapolation,
                        "duration_preserve_total": args.duration_preserve_total,
                        "duration_soft_cap_frames": (
                            args.duration_soft_cap_frames
                        ),
                        "duration_frames": int(durations.sum()),
                        "negative_duration_values": negative,
                    }
                )
                if len(pending) >= args.flush_every:
                    append_jsonl(partial_handle, pending)
                    output_rows.extend(pending)
                    pending.clear()
                if index % 10 == 0 or index + 1 == len(sources):
                    completed = len(output_rows) + len(pending)
                    print(
                        f"synthesized={completed}/{total} "
                        f"elapsed={time.time() - started:.1f}s",
                        flush=True,
                    )
        if pending:
            append_jsonl(partial_handle, pending)
            output_rows.extend(pending)
            pending.clear()
    write_jsonl(out_dir / "anon.jsonl", output_rows)
    write_json(
        out_dir / "run_meta.json",
        {
            "args": vars(args),
            "records": len(output_rows),
            "resume_records": len(resume_rows),
            "partial_records": str(partial_path),
            "negative_duration_values": negative_duration_values,
            "elapsed_seconds": time.time() - started,
            "vocoder_version": generator_checkpoint.get("step"),
            "target_embedding_key": args.target_embedding_key,
            "target_embedding_mode": args.target_embedding_mode,
            "duration_embedding_key": args.duration_embedding_key,
            "input_sha256": {
                "source_manifest": sha256_file(args.source_manifest),
                "unit_records": sha256_file(args.unit_records),
                "target_map": sha256_file(args.target_map),
                "vocoder": sha256_file(args.vocoder),
                "vocoder_embeddings": sha256_file(args.vocoder_embeddings),
                **(
                    {"duration_model": sha256_file(args.duration_model)}
                    if args.duration_model
                    else {}
                ),
                **(
                    {
                        "duration_embeddings": sha256_file(
                            args.duration_embeddings
                        )
                    }
                    if args.duration_embeddings
                    else {}
                ),
            },
        },
    )
    print(out_dir / "anon.jsonl")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
