"""HuBERT feature extraction and deterministic K-means unit tokenisation."""

from __future__ import annotations

import argparse
import json
import os
import random
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
import torch
from sklearn.cluster import MiniBatchKMeans
from torch.utils.data import DataLoader, Dataset

from n019.audio import HOP_SAMPLES, load_audio_16k
from n019.manifest import (
    append_jsonl,
    iter_jsonl,
    safe_filename,
    sha256_file,
    speaker_id,
    utterance_id,
    write_json,
    write_jsonl,
)


@dataclass(frozen=True)
class HubertUnitConfig:
    model_id: str = "facebook/hubert-base-ls960"
    model_revision: str = "dba3bb02fda4248b6e082697eee756de8fe8aa8a"
    layer: int = 6
    vocabulary_size: int = 200
    km_batch_size: int = 4096
    km_buffer_frames: int = 262_144
    km_n_init: int = 3
    km_max_iter: int = 100
    km_tol: float = 1e-4
    seed: int = 20261102


class AudioManifestDataset(Dataset):
    def __init__(self, rows: list[dict]) -> None:
        self.rows = rows

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, dict]:
        row = self.rows[index]
        return load_audio_16k(row["audio"]), row


def collate_audio(batch):
    waveforms, rows = zip(*batch)
    return list(waveforms), list(rows)


def save_array_atomic(path: str | Path, array: np.ndarray) -> None:
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    with temporary.open("wb") as handle:
        np.save(handle, array)
    os.replace(temporary, destination)


def load_resume_records(
    path: str | Path,
    *,
    valid_ids: set[str],
    code_dir: str | Path,
    k: int,
    layer: int,
    codebook_path: str | Path | None = None,
) -> list[dict]:
    """Load and validate records written before an interrupted extraction."""
    records = list(iter_jsonl(path))
    seen: set[str] = set()
    code_dir = Path(code_dir).resolve()
    for record in records:
        identifier = utterance_id(record)
        if identifier in seen:
            raise ValueError(f"Duplicate resume record: {identifier}")
        if identifier not in valid_ids:
            raise ValueError(f"Resume record not in manifest: {identifier}")
        if int(record.get("kmeans_k", -1)) != k:
            raise ValueError(f"Resume K mismatch for {identifier}")
        if int(record.get("hubert_layer", -1)) != layer:
            raise ValueError(f"Resume HuBERT layer mismatch for {identifier}")
        if codebook_path is not None:
            expected_codebook = Path(codebook_path).resolve()
            actual_codebook = Path(record["kmeans_codebook"]).resolve()
            if actual_codebook != expected_codebook:
                raise ValueError(
                    f"Resume codebook mismatch for {identifier}: "
                    f"{actual_codebook} != {expected_codebook}"
                )
        expected_path = (code_dir / safe_filename(identifier, ".npy")).resolve()
        actual_path = Path(record["codes_path"]).resolve()
        if actual_path != expected_path:
            raise ValueError(
                f"Resume code path mismatch for {identifier}: "
                f"{actual_path} != {expected_path}"
            )
        if not actual_path.is_file():
            raise FileNotFoundError(actual_path)
        if int(record.get("num_frames", 0)) <= 0:
            raise ValueError(f"Resume record has no frames: {identifier}")
        seen.add(identifier)
    return records


class HubertFrameExtractor:
    def __init__(
        self,
        model_path: str | Path,
        device: torch.device,
        *,
        layer: int = 6,
    ) -> None:
        from transformers import AutoFeatureExtractor, HubertModel

        self.device = device
        self.feature_extractor = AutoFeatureExtractor.from_pretrained(
            str(model_path),
            local_files_only=True,
        )
        self.model = HubertModel.from_pretrained(
            str(model_path),
            local_files_only=True,
        ).to(device).eval()
        self.hidden_size = int(self.model.config.hidden_size)
        self.layer = int(layer)
        if self.layer < 0 or self.layer > self.model.config.num_hidden_layers:
            raise ValueError(
                f"HuBERT layer {self.layer} outside "
                f"[0, {self.model.config.num_hidden_layers}]"
            )

    @torch.inference_mode()
    def extract(
        self,
        waveforms: list[torch.Tensor],
    ) -> tuple[list[torch.Tensor], list[int]]:
        if not waveforms:
            return [], []
        processed = self.feature_extractor(
            [waveform.cpu().numpy() for waveform in waveforms],
            sampling_rate=16_000,
            return_tensors="pt",
            padding=True,
            return_attention_mask=True,
        )
        input_values = processed["input_values"].to(self.device)
        attention_mask = processed["attention_mask"].to(self.device)
        outputs = self.model(
            input_values=input_values,
            attention_mask=attention_mask,
            output_hidden_states=True,
            return_dict=True,
        )
        hidden = outputs.hidden_states[self.layer]
        if hidden.shape[-1] != self.hidden_size:
            raise RuntimeError(
                f"HuBERT produced {hidden.shape[-1]}-D features, "
                f"expected {self.hidden_size}"
            )
        input_lengths = attention_mask.sum(dim=1).to(torch.long)
        output_lengths = torch.tensor(
            [
                feature_output_length(
                    int(length),
                    self.model.config.conv_stride,
                    self.model.config.conv_kernel,
                )
                for length in input_lengths.cpu().tolist()
            ],
            dtype=torch.long,
        )
        frames = []
        for index, length in enumerate(output_lengths.cpu().tolist()):
            if length <= 0:
                raise RuntimeError(
                    f"Waveform {index} is too short for HuBERT: "
                    f"{waveforms[index].numel()} samples"
                )
            frames.append(hidden[index, :length].detach().cpu())
        return frames, output_lengths.cpu().tolist()


def feature_output_length(
    samples: int,
    strides: list[int] | tuple[int, ...],
    kernels: list[int] | tuple[int, ...],
) -> int:
    """Apply the HuBERT convolutional output-length formula exactly."""
    if samples < 0:
        raise ValueError("samples must be non-negative")
    if len(strides) != len(kernels):
        raise ValueError("strides and kernels must have equal length")
    length = samples
    for stride, kernel in zip(strides, kernels):
        if stride <= 0 or kernel <= 0:
            raise ValueError("convolution stride and kernel must be positive")
        length = max(0, (length - kernel) // stride + 1)
    return length


class KMeansCodebook:
    def __init__(self, centroids: torch.Tensor, metadata: dict | None = None) -> None:
        if centroids.ndim != 2:
            raise ValueError("K-means centroids must have shape [K, D]")
        if centroids.shape[0] == 0 or centroids.shape[1] == 0:
            raise ValueError("K-means centroids must be non-empty")
        if not bool(torch.isfinite(centroids).all()):
            raise ValueError("K-means centroids contain non-finite values")
        self.centroids = centroids.float()
        self.metadata = metadata or {}

    @classmethod
    def load(cls, path: str | Path) -> "KMeansCodebook":
        archive = np.load(path, allow_pickle=False)
        centroids = torch.from_numpy(archive["centroids"].astype(np.float32))
        metadata: dict = {}
        if "metadata_json" in archive:
            metadata = json.loads(str(archive["metadata_json"].item()))
        archive.close()
        return cls(centroids, metadata)

    def save(self, path: str | Path, metadata: dict) -> None:
        destination = Path(path)
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = destination.with_suffix(destination.suffix + ".tmp")
        with temporary.open("wb") as handle:
            np.savez(
                handle,
                centroids=self.centroids.numpy(),
                metadata_json=np.array(
                    json.dumps(metadata, ensure_ascii=True)
                ),
            )
        os.replace(temporary, destination)

    def assign(
        self,
        features: torch.Tensor,
        *,
        device: torch.device,
        chunk_size: int = 32_768,
    ) -> torch.Tensor:
        if features.ndim != 2:
            raise ValueError("features must have shape [frames, dim]")
        if features.shape[1] != self.centroids.shape[1]:
            raise ValueError(
                f"Feature dimension {features.shape[1]} does not match "
                f"codebook dimension {self.centroids.shape[1]}"
            )
        if not bool(torch.isfinite(features).all()):
            raise ValueError("HuBERT features contain non-finite values")
        outputs = []
        centroids = self.centroids.to(device)
        centroid_norm = centroids.square().sum(dim=1)
        for start in range(0, features.shape[0], chunk_size):
            block = features[start : start + chunk_size].float().to(device)
            distances = (
                block.square().sum(dim=1, keepdim=True)
                - 2 * block @ centroids.T
                + centroid_norm.unsqueeze(0)
            )
            outputs.append(distances.argmin(dim=1).cpu())
        return torch.cat(outputs) if outputs else torch.empty(0, dtype=torch.long)


def fit_kmeans(
    extractor: HubertFrameExtractor,
    loader: DataLoader,
    config: HubertUnitConfig,
    *,
    device: torch.device,
    limit_utterances: int = 0,
) -> tuple[KMeansCodebook, dict]:
    kmeans = MiniBatchKMeans(
        n_clusters=config.vocabulary_size,
        batch_size=config.km_batch_size,
        n_init=config.km_n_init,
        max_iter=config.km_max_iter,
        tol=config.km_tol,
        random_state=config.seed,
        reassignment_ratio=0.01,
        verbose=0,
    )
    buffer: list[np.ndarray] = []
    buffered_frames = 0
    total_frames = 0
    utterances = 0
    fitted_batches = 0
    started = time.time()

    def update_from_buffer() -> None:
        nonlocal buffered_frames, fitted_batches
        if not buffer:
            return
        combined = np.concatenate(buffer, axis=0)
        buffer.clear()
        buffered_frames = 0
        if not hasattr(kmeans, "cluster_centers_"):
            if combined.shape[0] < config.vocabulary_size:
                raise RuntimeError(
                    f"Only {combined.shape[0]} frames available for "
                    f"{config.vocabulary_size} clusters"
                )
        for start in range(0, combined.shape[0], config.km_batch_size):
            batch = combined[start : start + config.km_batch_size]
            if not hasattr(kmeans, "cluster_centers_") and (
                batch.shape[0] < config.vocabulary_size
            ):
                continue
            kmeans.partial_fit(batch)
            fitted_batches += 1

    for waveforms, _ in loader:
        frames, _ = extractor.extract(waveforms)
        for item in frames:
            array = item.numpy().astype(np.float32, copy=False)
            buffer.append(array)
            buffered_frames += array.shape[0]
            total_frames += array.shape[0]
        utterances += len(waveforms)
        threshold = max(config.km_buffer_frames, config.vocabulary_size)
        if buffered_frames >= threshold:
            update_from_buffer()
            print(
                f"kmeans_fit utterances={utterances} "
                f"frames={total_frames} batches={fitted_batches} "
                f"elapsed={time.time() - started:.1f}s",
                flush=True,
            )
        if limit_utterances and utterances >= limit_utterances:
            break
    if buffer:
        update_from_buffer()
    if not hasattr(kmeans, "cluster_centers_"):
        raise RuntimeError("K-means did not receive any training frames")
    if kmeans.cluster_centers_.shape[0] != config.vocabulary_size:
        raise RuntimeError(
            f"Expected {config.vocabulary_size} K-means centres, "
            f"got {kmeans.cluster_centers_.shape[0]}"
        )
    metadata = {
        "algorithm": "MiniBatchKMeans",
        "vocabulary_size": config.vocabulary_size,
        "fit_utterances": utterances,
        "fit_frames": total_frames,
        "buffer_frames": max(config.km_buffer_frames, config.vocabulary_size),
        "fitted_batches": fitted_batches,
        "batch_size": config.km_batch_size,
        "n_init": config.km_n_init,
        "max_iter": config.km_max_iter,
        "tol": config.km_tol,
        "seed": config.seed,
        "inertia": float(kmeans.inertia_),
        "n_iter": int(
            getattr(kmeans, "n_iter_", getattr(kmeans, "n_steps_", -1))
        ),
        "n_steps": int(getattr(kmeans, "n_steps_", -1)),
    }
    return KMeansCodebook(torch.from_numpy(kmeans.cluster_centers_)), metadata


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract HuBERT layer-6 units and K=200 k-means tokens."
    )
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--hubert-model", required=True)
    parser.add_argument("--codebook", default=None)
    parser.add_argument("--fit-only", action="store_true")
    parser.add_argument("--limit-utterances", type=int, default=0)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--kmeans-buffer-frames", type=int, default=262_144)
    parser.add_argument("--layer", type=int, default=6)
    parser.add_argument("--k", type=int, default=200)
    parser.add_argument("--seed", type=int, default=20261102)
    parser.add_argument("--device", default="cuda")
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Continue from unit_records.partial.jsonl without redoing rows.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.k <= 0:
        raise ValueError("--k must be positive")
    if args.batch_size <= 0 or args.kmeans_buffer_frames <= 0:
        raise ValueError("batch size and K-means buffer must be positive")
    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA/DCU requested but unavailable")
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    device = torch.device(args.device)
    rows = list(iter_jsonl(args.manifest))
    if args.limit_utterances:
        rows = rows[: args.limit_utterances]
    if not rows:
        raise ValueError("Manifest is empty")
    identifiers = [utterance_id(row) for row in rows]
    if len(identifiers) != len(set(identifiers)):
        raise ValueError("Manifest contains duplicate utterance IDs")

    out = Path(args.out)
    code_dir = out / "codes"
    code_dir.mkdir(parents=True, exist_ok=True)
    partial_path = out / "unit_records.partial.jsonl"
    resume_records: list[dict] = []
    if args.resume:
        if not args.codebook:
            raise ValueError("--resume requires --codebook")
        if not partial_path.is_file():
            raise FileNotFoundError(partial_path)
        resume_records = load_resume_records(
            partial_path,
            valid_ids=set(identifiers),
            code_dir=code_dir,
            k=args.k,
            layer=args.layer,
            codebook_path=args.codebook,
        )
        completed_ids = {
            utterance_id(record) for record in resume_records
        }
        rows = [
            row for row in rows if utterance_id(row) not in completed_ids
        ]
    elif partial_path.exists():
        raise FileExistsError(
            f"{partial_path} already exists; pass --resume to continue it"
        )
    else:
        write_jsonl(partial_path, [])

    dataset = AudioManifestDataset(rows)
    loader = DataLoader(
        dataset,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=args.workers,
        collate_fn=collate_audio,
        persistent_workers=args.workers > 0,
    )
    config = HubertUnitConfig(
        layer=args.layer,
        vocabulary_size=args.k,
        km_buffer_frames=args.kmeans_buffer_frames,
        seed=args.seed,
    )
    extractor = HubertFrameExtractor(
        args.hubert_model,
        device,
        layer=args.layer,
    )

    if args.codebook:
        codebook = KMeansCodebook.load(args.codebook)
        if codebook.centroids.shape[0] != args.k:
            raise ValueError("--k does not match loaded codebook")
        codebook_path = Path(args.codebook)
    else:
        codebook, fit_metadata = fit_kmeans(
            extractor,
            loader,
            config,
            device=device,
        )
        codebook_path = out / f"kmeans_k{args.k}_seed{args.seed}.npz"
        codebook.save(codebook_path, {**asdict(config), **fit_metadata})
    if args.fit_only:
        write_json(
            out / "kmeans_fit.json",
            {"codebook": str(codebook_path), **codebook.metadata},
        )
        print(codebook_path)
        return 0

    extracted_rows = list(resume_records)
    started = time.time()
    completed = len(extracted_rows)
    total = completed + len(rows)
    with partial_path.open("a", encoding="utf-8") as partial_handle:
        for waveforms, batch_rows in loader:
            frames, output_lengths = extractor.extract(waveforms)
            batch_records = []
            for frame, output_length, row in zip(
                frames, output_lengths, batch_rows
            ):
                labels = codebook.assign(frame, device=device)
                if labels.numel() != output_length:
                    raise RuntimeError(
                        f"Code count {labels.numel()} != HuBERT frames "
                        f"{output_length}"
                    )
                identifier = utterance_id(row)
                destination = code_dir / safe_filename(identifier, ".npy")
                save_array_atomic(
                    destination,
                    labels.numpy().astype(np.int16),
                )
                batch_records.append(
                    {
                        **row,
                        "id": identifier,
                        "codes_path": str(destination),
                        "num_frames": int(labels.numel()),
                        "num_frames_collapsed": int(
                            torch.unique_consecutive(labels).numel()
                        ),
                        "samples_used": int(output_length * HOP_SAMPLES),
                        "kmeans_codebook": str(codebook_path),
                        "kmeans_k": args.k,
                        "hubert_layer": args.layer,
                    }
                )
            append_jsonl(partial_handle, batch_records)
            extracted_rows.extend(batch_records)
            previous = completed
            completed += len(batch_records)
            if completed // 100 > previous // 100 or completed == total:
                print(
                    f"extracted={completed}/{total} "
                    f"elapsed={time.time() - started:.1f}s",
                    flush=True,
                )

    records_path = out / "unit_records.jsonl"
    write_jsonl(records_path, extracted_rows)
    metadata = {
        "manifest": str(Path(args.manifest).resolve()),
        "records": len(extracted_rows),
        "speakers": len({speaker_id(row) for row in extracted_rows}),
        "codebook": str(codebook_path),
        "codebook_sha256": sha256_file(codebook_path),
        "kmeans_k": args.k,
        "hubert_layer": args.layer,
        "hubert_model": str(Path(args.hubert_model).resolve()),
        "hubert_revision": config.model_revision,
        "resume_records": len(resume_records),
        "partial_records": str(partial_path),
        "frame_shift_seconds": HOP_SAMPLES / 16_000,
        "samples_per_frame": HOP_SAMPLES,
        "torch": torch.__version__,
        "hip": torch.version.hip,
        "elapsed_seconds": time.time() - started,
    }
    write_json(out / "units_metadata.json", metadata)
    print(records_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
