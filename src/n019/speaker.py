"""Speaker embedding extractors used for duration and vocoder conditioning."""

from __future__ import annotations

import importlib.util
from pathlib import Path

import torch
import torch.nn.functional as F

from n019.audio import normalize_loudness, read_audio, resample_audio


def _load_wpro_class(model_dir: Path):
    source = model_dir / "spk_embeddings.py"
    if not source.is_file():
        raise FileNotFoundError(source)
    spec = importlib.util.spec_from_file_location("n019_wpro_embeddings", source)
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot import {source}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.EmbeddingsModel


def load_wpro(model_dir: str | Path, device: torch.device) -> torch.nn.Module:
    model_dir = Path(model_dir)
    model_class = _load_wpro_class(model_dir)
    model = model_class.from_pretrained(
        str(model_dir),
        revision=None,
        local_files_only=True,
    )
    return model.to(device).eval()


class SpeakerEmbedder:
    """Uniform interface for NT/W-PRO and official VPC ECAPA embeddings."""

    def __init__(
        self,
        kind: str,
        model_path: str | Path,
        device: torch.device,
        *,
        nt_max_samples: int | None = 320_000,
    ) -> None:
        if kind not in {"nt", "ecapa"}:
            raise ValueError(f"Unsupported speaker embedding kind: {kind}")
        self.kind = kind
        self.device = device
        self.model_path = Path(model_path)
        if kind == "nt":
            if nt_max_samples is not None and nt_max_samples <= 0:
                raise ValueError("nt_max_samples must be positive or None")
            self.model = load_wpro(self.model_path, device)
            self.dimension = 250
            self.classifier = None
            self.nt_max_samples = nt_max_samples
        else:
            from speechbrain.pretrained import EncoderClassifier

            self.classifier = EncoderClassifier.from_hparams(
                source=str(self.model_path),
                savedir=str(self.model_path),
                run_opts={"device": str(device)},
            )
            self.model = None
            self.dimension = 192
            self.nt_max_samples = None

    @torch.inference_mode()
    def embed(self, waveform: torch.Tensor, sample_rate: int = 16_000) -> torch.Tensor:
        if waveform.ndim != 1:
            raise ValueError("SpeakerEmbedder expects one mono waveform")
        waveform = waveform.float()
        if waveform.numel() == 0:
            raise ValueError("SpeakerEmbedder received empty audio")
        if not torch.isfinite(waveform).all():
            raise ValueError("SpeakerEmbedder received non-finite audio")
        if self.kind == "nt":
            waveform = resample_audio(waveform, sample_rate).to(self.device)
            if float(waveform.std()) <= 1e-8:
                raise ValueError("W-PRO requires a non-constant waveform")
            if (
                self.nt_max_samples is not None
                and waveform.numel() > self.nt_max_samples
            ):
                waveform = waveform[: self.nt_max_samples]
            embedding = self.model(waveform.unsqueeze(0))
            embedding = F.normalize(embedding.squeeze(0), dim=0)
        else:
            waveform = normalize_loudness(waveform, sample_rate).to(self.device)
            if not torch.isfinite(waveform).all():
                raise ValueError("ECAPA preprocessing produced non-finite audio")
            nonzero = torch.nonzero(torch.abs(waveform) > 1e-8).flatten()
            if nonzero.numel():
                waveform = waveform[nonzero[0] : nonzero[-1] + 1]
            if waveform.numel() == 0:
                raise ValueError("ECAPA received audio containing only zeros")
            embedding = self.classifier.encode_batch(waveform.unsqueeze(0))
            embedding = embedding.reshape(-1)
        if not torch.isfinite(embedding).all():
            raise ValueError(f"{self.kind} produced a non-finite embedding")
        if embedding.numel() != self.dimension:
            raise RuntimeError(
                f"{self.kind} embedding has {embedding.numel()} dimensions, "
                f"expected {self.dimension}"
            )
        return embedding.float().cpu()

    def embed_file(self, path: str | Path) -> torch.Tensor:
        waveform, sample_rate = read_audio(path)
        return self.embed(waveform, sample_rate)
