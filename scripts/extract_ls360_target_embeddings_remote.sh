#!/usr/bin/env bash

set -euo pipefail
umask 0002

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
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

MANIFEST="$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_manifest.jsonl"
OUT="$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_360_target_nt_utterance"
MODEL="$N019_OFFICIAL_MODELS/wpro"

for required in \
  "$MANIFEST" \
  "$MODEL/config.json" \
  "$MODEL/model.safetensors" \
  "$MODEL/spk_embeddings.py"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing LS360 target embedding input: $required" >&2
    exit 1
  fi
done

mkdir -p "$OUT" "$N019_OFFICIAL_LOGS"
if [[ "$(id -u)" == "0" ]]; then
  owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
  chown "$owner" "$OUT"
fi
RESUME_FLAG=()
if [[ -f "$OUT/partial_embeddings.npz" ]]; then
  RESUME_FLAG=(--resume)
fi

{
  echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
  echo "job=${SLURM_JOB_ID:-manual} scope=ls360_target_embeddings"
  echo "manifest=$MANIFEST"
  echo "rows=$(wc -l < "$MANIFEST")"
  echo "out=$OUT"
  echo "resume=${#RESUME_FLAG[@]}"
} | tee "$OUT/launch.txt"

python -u -m n019.extract_speakers \
  --manifest "$MANIFEST" \
  --model "$MODEL" \
  --kind nt \
  --level utterance \
  --checkpoint-every 500 \
  --device cuda \
  --out "$OUT" \
  "${RESUME_FLAG[@]}"

if [[ "$(id -u)" == "0" ]]; then
  owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
  chown -R "$owner" "$OUT"
fi

echo "LS360_TARGET_EMBEDDINGS_COMPLETE out=$OUT"
