"""Extract NT/W-PRO or official VPC ECAPA embeddings from a JSONL manifest."""

from __future__ import annotations

import argparse
import json
import os
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
import torch

from n019.audio import read_audio
from n019.manifest import (
    iter_jsonl,
    speaker_id,
    utterance_id,
    write_json,
    write_jsonl,
)
from n019.speaker import SpeakerEmbedder


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract speaker embeddings for N019 conditioning."
    )
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--kind", choices=["nt", "ecapa"], required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument(
        "--level",
        choices=["speaker", "utterance"],
        default="speaker",
    )
    parser.add_argument("--max-utterances-per-speaker", type=int, default=0)
    parser.add_argument("--checkpoint-every", type=int, default=500)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--device", default="cuda")
    return parser.parse_args()


def save_npz_atomic(path: Path, values: dict[str, torch.Tensor]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    arrays = {key: value.numpy() for key, value in values.items()}
    with temporary.open("wb") as handle:
        np.savez(handle, **arrays)
    os.replace(temporary, path)


def load_partial_embeddings(
    path: Path,
    *,
    level: str,
) -> dict[str, torch.Tensor]:
    if level not in {"speaker", "utterance"}:
        raise ValueError(f"Unsupported embedding level: {level}")
    if not path.is_file():
        return {}
    archive = np.load(path, allow_pickle=False)
    values = {
        key: torch.from_numpy(archive[key].astype(np.float32))
        for key in archive.files
    }
    archive.close()
    return values


def main() -> int:
    args = parse_args()
    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA/DCU requested but unavailable")
    rows = list(iter_jsonl(args.manifest))
    if not rows:
        raise ValueError("Manifest is empty")
    device = torch.device(args.device)
    embedder = SpeakerEmbedder(args.kind, args.model, device)
    grouped: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        grouped[speaker_id(row)].append(row)

    output_dir = Path(args.out)
    partial_path = output_dir / "partial_embeddings.npz"
    resumed_values = (
        load_partial_embeddings(partial_path, level=args.level)
        if args.resume
        else {}
    )
    utterance_embeddings: dict[str, torch.Tensor] = (
        resumed_values if args.level == "utterance" else {}
    )
    speaker_embeddings: dict[str, torch.Tensor] = (
        resumed_values if args.level == "speaker" else {}
    )
    resumed = len(resumed_values)
    output_rows = []
    started = time.time()
    completed = 0
    for speaker, speaker_rows in sorted(grouped.items()):
        if args.max_utterances_per_speaker:
            speaker_rows = speaker_rows[: args.max_utterances_per_speaker]
        if args.level == "speaker" and speaker in speaker_embeddings:
            for row in speaker_rows:
                identifier = utterance_id(row)
                output_rows.append(
                    {
                        "id": identifier,
                        "speaker": speaker,
                        "audio": row["audio"],
                        "kind": args.kind,
                        "embedding_key": speaker,
                        "embedding_level": args.level,
                        "dimension": embedder.dimension,
                    }
                )
            completed += len(speaker_rows)
            continue
        vectors = []
        for row in speaker_rows:
            identifier = utterance_id(row)
            if identifier in utterance_embeddings:
                vector = utterance_embeddings[identifier]
            else:
                waveform, sample_rate = read_audio(row["audio"])
                vector = embedder.embed(waveform, sample_rate)
            utterance_embeddings[identifier] = vector
            vectors.append(vector)
            output_rows.append(
                {
                    "id": identifier,
                    "speaker": speaker,
                    "audio": row["audio"],
                    "kind": args.kind,
                    "embedding_key": identifier,
                    "dimension": int(vector.numel()),
                }
            )
            completed += 1
            if completed % args.checkpoint_every == 0:
                temporary_values = (
                    utterance_embeddings
                    if args.level == "utterance"
                    else speaker_embeddings
                )
                save_npz_atomic(partial_path, temporary_values)
                print(
                    f"extracted={completed} speakers={len(grouped)} "
                    f"elapsed={time.time() - started:.1f}s",
                    flush=True,
                )
        if not vectors:
            raise RuntimeError(f"No embeddings extracted for speaker {speaker}")
        mean = torch.stack(vectors).mean(dim=0)
        if args.kind == "nt":
            mean = torch.nn.functional.normalize(mean, dim=0)
        speaker_embeddings[speaker] = mean

    output_dir.mkdir(parents=True, exist_ok=True)
    values = (
        speaker_embeddings
        if args.level == "speaker"
        else utterance_embeddings
    )
    npz_path = output_dir / f"{args.kind}_{args.level}_embeddings.npz"
    save_npz_atomic(npz_path, values)
    for row in output_rows:
        row["embedding_level"] = args.level
        row["embedding_key"] = (
            row["speaker"] if args.level == "speaker" else row["id"]
        )
    write_jsonl(output_dir / f"{args.kind}_{args.level}_manifest.jsonl", output_rows)
    write_json(
        output_dir / "metadata.json",
        {
            "kind": args.kind,
            "level": args.level,
            "model": str(Path(args.model).resolve()),
            "speakers": len(speaker_embeddings),
            "utterances": len(utterance_embeddings),
            "dimension": embedder.dimension,
            "nt_max_samples": embedder.nt_max_samples,
            "resumed_entries": resumed,
            "embeddings": str(npz_path),
            "elapsed_seconds": time.time() - started,
        },
    )
    print(json.dumps({"embeddings": str(npz_path), "count": len(values)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
