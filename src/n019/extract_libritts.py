"""Legacy LibriTTS-R extraction; not valid for formal N019 training."""

from __future__ import annotations

import argparse
import io
import json
import time
from pathlib import Path

import librosa
import numpy as np
import pyarrow.parquet as pq
import soundfile as sf


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--shards", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument(
        "--allow-legacy-libritts-r",
        action="store_true",
        help="Explicitly acknowledge that this is not the paper's LibriTTS data.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.allow_legacy_libritts_r:
        raise SystemExit(
            "This legacy entry point operates on LibriTTS-R parquet data. "
            "Formal N019 vocoder training must use original LibriTTS. Pass "
            "--allow-legacy-libritts-r only for exploratory diagnostics."
        )
    shards = sorted(Path(args.shards).glob("*.parquet"))
    if not shards:
        raise FileNotFoundError(f"No parquet shards under {args.shards}")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    manifest = Path(args.manifest)
    manifest.parent.mkdir(parents=True, exist_ok=True)

    started = time.time()
    written = 0
    with manifest.open("w", encoding="utf-8") as output:
        for shard_index, shard in enumerate(shards):
            parquet = pq.ParquetFile(shard)
            for batch in parquet.iter_batches(batch_size=32):
                rows = batch.to_pylist()
                for row in rows:
                    audio = row["audio"]
                    waveform, sample_rate = sf.read(
                        io.BytesIO(audio["bytes"]),
                        dtype="float32",
                        always_2d=True,
                    )
                    waveform = waveform.mean(axis=1)
                    if sample_rate != 16_000:
                        waveform = librosa.resample(
                            waveform,
                            orig_sr=sample_rate,
                            target_sr=16_000,
                        )
                    speaker = str(row["speaker_id"])
                    chapter = str(row["chapter_id"])
                    utterance_id = str(row["id"])
                    output_path = out / speaker / chapter / f"{utterance_id}.wav"
                    output_path.parent.mkdir(parents=True, exist_ok=True)
                    sf.write(
                        output_path,
                        waveform.astype(np.float32),
                        16_000,
                        subtype="PCM_16",
                    )
                    output.write(
                        json.dumps(
                            {
                                "audio": str(output_path),
                                "speaker": speaker,
                                "chapter": chapter,
                                "id": utterance_id,
                                "text": row["text_normalized"],
                                "seconds": float(waveform.size / 16_000),
                                "source_shard": shard.name,
                                "source_sample_rate": int(sample_rate),
                            },
                            ensure_ascii=False,
                        )
                        + "\n"
                    )
                    written += 1
                    if written % 500 == 0:
                        print(
                            f"shard={shard_index + 1}/{len(shards)} "
                            f"written={written} elapsed={time.time() - started:.1f}s"
                        )
                    if args.limit and written >= args.limit:
                        print(f"wrote={written} manifest={manifest}")
                        return 0
    print(f"wrote={written} manifest={manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
