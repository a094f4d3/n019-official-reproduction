#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
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
fi
if [[ -z "$ROOT" ]]; then
  echo "Cannot locate n019_official project root" >&2
  exit 1
fi
export N019_VOICE_ROOT="$(cd "$ROOT/../.." && pwd)"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

MANIFEST="$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360.jsonl"
OUT="$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_360"
CODEBOOK="$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_100/kmeans_k200_seed20261102.npz"
HUBERT="$N019_OFFICIAL_MODELS/hubert"
BATCH_SIZE="${N019_UNIT_BATCH_SIZE:-8}"
WORKERS="${N019_UNIT_WORKERS:-4}"
MAX_SECONDS="${N019_UNIT_MAX_SECONDS:-21600}"

for required in "$MANIFEST" "$CODEBOOK" "$HUBERT/config.json"; do
  if [[ ! -e "$required" ]]; then
    echo "Missing LS360 unit input: $required" >&2
    exit 1
  fi
done

mkdir -p "$OUT" "$N019_OFFICIAL_LOGS"
RESUME_FLAG=()
if [[ -f "$OUT/unit_records.partial.jsonl" ]]; then
  RESUME_FLAG=(--resume)
fi

{
  echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
  echo "job=${SLURM_JOB_ID:-manual} scope=ls360_units"
  echo "manifest=$MANIFEST"
  echo "out=$OUT"
  echo "batch_size=$BATCH_SIZE workers=$WORKERS"
  echo "max_seconds=$MAX_SECONDS"
  echo "resume=${#RESUME_FLAG[@]}"
  python -c "import torch; print('torch=' + torch.__version__); print('hip=' + str(torch.version.hip)); print('dcu_available=' + str(torch.cuda.is_available()))"
} | tee "$OUT/launch.txt"

export N019_PREFLIGHT_MANIFEST="$MANIFEST"
bash "$ROOT/scripts/preflight_dcu_remote.sh"

timeout --signal=TERM "$MAX_SECONDS" python -u -m n019.units \
  --manifest "$MANIFEST" \
  --out "$OUT" \
  --hubert-model "$HUBERT" \
  --codebook "$CODEBOOK" \
  --batch-size "$BATCH_SIZE" \
  --workers "$WORKERS" \
  --device cuda \
  "${RESUME_FLAG[@]}"

python "$ROOT/scripts/verify_unit_dataset.py" \
  --manifest "$MANIFEST" \
  --unit-records "$OUT/unit_records.jsonl" \
  --codebook "$CODEBOOK" \
  --expected-records 104014 \
  --expected-speakers 921 \
  --out "$OUT/verification.json"

echo "LS360_UNITS_COMPLETE out=$OUT"
