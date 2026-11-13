#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -f "$ROOT/hpc/activate_n019_official.sh" ]]; then
  ROOT=""
  for candidate in \
    /mnt/data/voice_projects/code/n019_official \
    "/public/home/$(id -un)/voice_projects/code/n019_official" \
    "$HOME/voice_projects/code/n019_official"; do
    if [[ -d "$candidate" ]]; then
      ROOT="$candidate"
      break
    fi
  done
fi

if [[ -z "${ROOT:-}" ]]; then
  echo "Cannot locate n019_official project root" >&2
  echo "user=$(id -un) home=$HOME" >&2
  exit 1
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

if ! python -c "import torch; raise SystemExit(0 if torch.cuda.is_available() else 1)"; then
  echo "DCU preflight requires a compute-node allocation" >&2
  exit 1
fi

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

python - <<'PY'
import torch

from n019.spectral import mel_spectrogram

count = torch.cuda.device_count()
if count < 1:
    raise SystemExit("No visible DCU")
for index in range(count):
    device = torch.device("cuda", index)
    with torch.cuda.device(device):
        waveform = torch.randn(2, 16_000, device=device, dtype=torch.float32)
        mel = mel_spectrogram(waveform)
        if not bool(torch.isfinite(mel).all()):
            raise SystemExit(f"Non-finite mel frontend on cuda:{index}")
    torch.cuda.synchronize(device)
    print(
        f"mel_preflight_ok device=cuda:{index} "
        f"shape={tuple(mel.shape)} dtype={mel.dtype}"
    )
PY

job_id="${SLURM_JOB_ID:-manual}"
preflight_manifest="${N019_PREFLIGHT_MANIFEST:-}"
if [[ -z "$preflight_manifest" ]]; then
  for candidate in \
    "$N019_OFFICIAL_DATA/processed/manifests/libritts_train_clean_100.jsonl" \
    "$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360.jsonl" \
    "$N019_OFFICIAL_DATA/processed/manifests/libri_test.jsonl" \
    "$N019_OFFICIAL_DATA/processed/units/libritts_train_clean_100/unit_records.jsonl"; do
    if [[ -f "$candidate" ]]; then
      preflight_manifest="$candidate"
      break
    fi
  done
fi
if [[ -z "$preflight_manifest" || ! -f "$preflight_manifest" ]]; then
  echo "No diagnostic manifest found for HuBERT preflight" >&2
  exit 1
fi
python -u -m n019.diagnose_hubert \
  --hubert-model "$N019_OFFICIAL_MODELS/hubert" \
  --manifest "$preflight_manifest" \
  --out "$N019_OFFICIAL_RUNS/preflight_${job_id}.json" \
  --quick
