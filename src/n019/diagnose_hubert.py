"""Minimal HuBERT/DCU diagnostic for architecture-specific kernel failures."""

from __future__ import annotations

import argparse
import json
import os
import platform
import traceback
from pathlib import Path

import torch
import torch.nn.functional as F

from n019.audio import load_audio_16k
from n019.manifest import iter_jsonl, write_json


def device_report() -> dict:
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA/DCU is unavailable")
    properties = torch.cuda.get_device_properties(0)
    return {
        "hostname": platform.node(),
        "torch": torch.__version__,
        "hip": torch.version.hip,
        "device_name": properties.name,
        "gcn_arch_name": getattr(properties, "gcnArchName", "unknown"),
        "total_memory_bytes": properties.total_memory,
        "amd_serialize_kernel": os.environ.get("AMD_SERIALIZE_KERNEL", ""),
        "amdgpu_targets": os.environ.get("AMDGPU_TARGETS", ""),
    }


def group_norm_probe(batch_size: int, frames: int, device: torch.device) -> dict:
    value = torch.randn(batch_size, 512, frames, device=device)
    weight = torch.ones(512, device=device)
    bias = torch.zeros(512, device=device)
    output = F.group_norm(value, 16, weight, bias)
    torch.cuda.synchronize()
    return {
        "output_shape": list(output.shape),
        "finite": bool(torch.isfinite(output).all()),
    }


class HubertProbe:
    def __init__(self, model_dir: Path, device: torch.device) -> None:
        from transformers import AutoFeatureExtractor, HubertModel

        self.device = device
        self.feature_extractor = AutoFeatureExtractor.from_pretrained(
            str(model_dir),
            local_files_only=True,
        )
        self.model = HubertModel.from_pretrained(
            str(model_dir),
            local_files_only=True,
        ).to(device).eval()

    @torch.inference_mode()
    def __call__(self, waveforms: list[torch.Tensor]) -> dict:
        processed = self.feature_extractor(
            [waveform.numpy() for waveform in waveforms],
            sampling_rate=16_000,
            return_tensors="pt",
            padding=True,
            return_attention_mask=True,
        )
        output = self.model(
            input_values=processed["input_values"].to(self.device),
            attention_mask=processed["attention_mask"].to(self.device),
            output_hidden_states=True,
            return_dict=True,
        )
        hidden = output.hidden_states[6]
        torch.cuda.synchronize()
        return {
            "batch_size": len(waveforms),
            "samples": [int(waveform.numel()) for waveform in waveforms],
            "hidden_shape": list(hidden.shape),
            "finite": bool(torch.isfinite(hidden).all()),
        }


def run_case(results: dict, name: str, function) -> None:
    print(f"CASE_START {name}", flush=True)
    try:
        detail = function()
        results[name] = {"status": "ok", **detail}
        print(f"CASE_OK {name} {json.dumps(detail, sort_keys=True)}", flush=True)
    except Exception as exc:
        results[name] = {
            "status": "failed",
            "exception": type(exc).__name__,
            "message": str(exc),
            "traceback": traceback.format_exc(),
        }
        print(f"CASE_FAILED {name} {type(exc).__name__}: {exc}", flush=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hubert-model", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument(
        "--quick",
        action="store_true",
        help="Run only GroupNorm and one short HuBERT forward.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    device = torch.device("cuda")
    model_dir = Path(args.hubert_model)
    rows = list(iter_jsonl(args.manifest))
    if len(rows) < 16:
        raise ValueError("Diagnostic manifest must contain at least 16 rows")
    results: dict[str, dict] = {}
    report = device_report()
    print(json.dumps(report, indent=2), flush=True)
    torch.manual_seed(0)
    hubert = HubertProbe(model_dir, device)

    run_case(
        results,
        "group_norm_b1_f500",
        lambda: group_norm_probe(1, 500, device),
    )
    run_case(
        results,
        "group_norm_b16_f500",
        lambda: group_norm_probe(16, 500, device),
    )
    run_case(
        results,
        "group_norm_b16_f1662",
        lambda: group_norm_probe(16, 1662, device),
    )
    group_norm_failed = any(
        detail["status"] != "ok"
        for name, detail in results.items()
        if name.startswith("group_norm_")
    )
    if args.quick and group_norm_failed:
        pass
    else:
        run_case(
            results,
            "hubert_synthetic_0.5s_b1",
            lambda: hubert([torch.zeros(8_000)]),
        )
        if not args.quick:
            run_remaining_cases(results, rows, hubert)

    failed = [
        name for name, detail in results.items() if detail["status"] != "ok"
    ]
    report["cases"] = results
    report["failed_cases"] = failed
    write_json(args.out, report)
    print(json.dumps({"failed_cases": failed, "out": args.out}, indent=2))
    return 1 if failed else 0


def run_remaining_cases(
    results: dict[str, dict],
    rows: list[dict],
    hubert: HubertProbe,
) -> None:
    run_case(
        results,
        "hubert_synthetic_10s_b16",
        lambda: hubert([torch.zeros(160_000) for _ in range(16)]),
    )
    first_rows = rows[:16]
    run_case(
        results,
        "hubert_manifest_first16",
        lambda: hubert([load_audio_16k(row["audio"]) for row in first_rows]),
    )
    longest = max(rows, key=lambda row: float(row["seconds"]))
    run_case(
        results,
        "hubert_manifest_longest_b1",
        lambda: hubert([load_audio_16k(longest["audio"])]),
    )


if __name__ == "__main__":
    raise SystemExit(main())
