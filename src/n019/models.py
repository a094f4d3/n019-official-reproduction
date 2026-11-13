"""Model loading helpers with explicit local-file behavior."""

from __future__ import annotations

import importlib.util
from pathlib import Path

import torch
from transformers import HubertModel


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


def load_wpro(model_dir: str | Path, device: str | torch.device = "cpu"):
    model_dir = Path(model_dir)
    model_class = _load_wpro_class(model_dir)
    model = model_class.from_pretrained(
        str(model_dir),
        revision=None,
        local_files_only=True,
    )
    return model.to(device).eval()


def load_hubert(model_dir: str | Path, device: str | torch.device = "cpu"):
    model = HubertModel.from_pretrained(
        str(Path(model_dir)),
        local_files_only=True,
    )
    return model.to(device).eval()


@torch.inference_mode()
def extract_hubert_layer(
    model: HubertModel,
    waveform: torch.Tensor,
    *,
    layer: int = 6,
) -> torch.Tensor:
    """Extract one HuBERT hidden layer from a mono 16 kHz waveform."""
    if waveform.ndim == 1:
        waveform = waveform.unsqueeze(0)
    if waveform.ndim != 2 or waveform.shape[0] != 1:
        raise ValueError("waveform must have shape [samples] or [1, samples]")
    outputs = model(
        input_values=waveform,
        output_hidden_states=True,
        return_dict=True,
    )
    hidden_states = outputs.hidden_states
    if layer < 0 or layer >= len(hidden_states):
        raise IndexError(f"layer {layer} outside [0, {len(hidden_states) - 1}]")
    return hidden_states[layer]


@torch.inference_mode()
def extract_wpro_embedding(model, waveform: torch.Tensor) -> torch.Tensor:
    if waveform.ndim == 1:
        waveform = waveform.unsqueeze(0)
    if waveform.ndim != 2 or waveform.shape[0] != 1:
        raise ValueError("waveform must have shape [samples] or [1, samples]")
    return model(waveform)
