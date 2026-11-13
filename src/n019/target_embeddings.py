"""Legacy LibriTTS-R target extraction; not valid for formal N019 results."""

from __future__ import annotations

import argparse
import io
import json
import time
from collections import defaultdict
from pathlib import Path

import librosa
import numpy as np
import pyarrow.parquet as pq
import soundfile as sf
import torch

from n019.models import extract_wpro_embedding, load_wpro


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--shards", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--models", default=None)
    parser.add_argument("--max-speakers", type=int, default=0)
    parser.add_argument("--candidates-per-speaker", type=int, default=4)
    parser.add_argument("--device", default="cuda")
    parser.add_argument(
        "--allow-legacy-libritts-r",
        action="store_true",
        help="Explicitly acknowledge that this is not the paper's LibriTTS data.",
    )
    return parser.parse_args()


def decode_audio(audio: dict) -> tuple[np.ndarray, int]:
    waveform, sample_rate = sf.read(
        io.BytesIO(audio["bytes"]),
        dtype="float32",
        always_2d=True,
    )
    return waveform.mean(axis=1), int(sample_rate)


def main() -> int:
    args = parse_args()
    if not args.allow_legacy_libritts_r:
        raise SystemExit(
            "This legacy entry point operates on LibriTTS-R parquet data. "
            "Formal N019 runs must use original LibriTTS manifests. Pass "
            "--allow-legacy-libritts-r only for exploratory diagnostics."
        )
    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA/DCU requested but unavailable")
    shards = sorted(Path(args.shards).rglob("*.parquet"))
    if not shards:
        raise FileNotFoundError(f"No parquet shards under {args.shards}")

    started = time.time()
    candidates: dict[str, list[dict]] = defaultdict(list)
    for shard in shards:
        parquet = pq.ParquetFile(shard)
        for batch in parquet.iter_batches(batch_size=32):
            for row in batch.to_pylist():
                speaker = str(row["speaker_id"])
                if len(candidates[speaker]) < args.candidates_per_speaker:
                    row["_source_shard"] = shard.name
                    candidates[speaker].append(row)

    speakers = sorted(candidates)
    if args.max_speakers:
        speakers = speakers[: args.max_speakers]
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    model_root = (
        Path(args.models)
        if args.models
        else Path.home() / "voice_projects/models/n019"
    )
    device = torch.device(args.device)
    model = load_wpro(model_root / "wpro", device)
    embeddings = {}
    manifest_rows = []
    with torch.inference_mode():
        for index, speaker in enumerate(speakers):
            best = None
            for row in candidates[speaker]:
                waveform, sample_rate = decode_audio(row["audio"])
                seconds = waveform.size / sample_rate
                score = abs(seconds - 5.0)
                if best is None or score < best[0]:
                    best = (score, row, waveform, sample_rate, seconds)
            if best is None:
                continue
            _, row, waveform, sample_rate, seconds = best
            if sample_rate != 16_000:
                waveform = librosa.resample(
                    waveform,
                    orig_sr=sample_rate,
                    target_sr=16_000,
                )
            speaker_dir = out / speaker
            speaker_dir.mkdir(parents=True, exist_ok=True)
            output_path = speaker_dir / f"{row['id']}.wav"
            sf.write(
                output_path,
                waveform.astype(np.float32),
                16_000,
                subtype="PCM_16",
            )
            audio_tensor = torch.from_numpy(waveform.astype(np.float32)).to(device)
            embedding = extract_wpro_embedding(model, audio_tensor)
            embedding = torch.nn.functional.normalize(
                embedding.squeeze(0).float(), dim=0
            )
            embeddings[speaker] = embedding.cpu().numpy()
            manifest_rows.append(
                {
                    "audio": str(output_path),
                    "speaker": speaker,
                    "id": str(row["id"]),
                    "chapter": str(row["chapter_id"]),
                    "text": row["text_normalized"],
                    "seconds": float(waveform.size / 16_000),
                    "source_sample_rate": sample_rate,
                    "source_shard": row["_source_shard"],
                }
            )
            print(
                f"embedded={index + 1}/{len(speakers)} speaker={speaker} "
                f"seconds={waveform.size / 16_000:.2f} "
                f"elapsed={time.time() - started:.1f}s",
                flush=True,
            )

    np.savez(out / "target_speaker_embeddings.npz", **embeddings)
    manifest = Path(args.manifest)
    manifest.parent.mkdir(parents=True, exist_ok=True)
    with manifest.open("w", encoding="utf-8") as handle:
        for row in manifest_rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")
    metadata = {
        "speakers": len(embeddings),
        "embedding_dim": int(next(iter(embeddings.values())).shape[0]),
        "shards": [str(path) for path in shards],
        "elapsed_seconds": time.time() - started,
        "device": str(device),
    }
    (out / "meta.json").write_text(
        json.dumps(metadata, indent=2), encoding="utf-8"
    )
    print(json.dumps(metadata, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
