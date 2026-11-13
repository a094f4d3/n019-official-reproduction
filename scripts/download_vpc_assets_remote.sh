#!/usr/bin/env bash

set -euo pipefail

MODELS="$HOME/voice_projects/models/n019_official/vpc"
LOG_DIR="$HOME/voice_projects/logs/n019_official"
mkdir -p "$MODELS" "$LOG_DIR"

ASR_URL="https://ghproxy.net/https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download/pre_model.zip/asr.zip"
ASR_SIZE=752987942
ASR_PART="$MODELS/asr.zip.part"
ASR_ZIP="$MODELS/asr.zip"

if [[ -f "$ASR_ZIP" ]]; then
  actual_size=$(stat -c '%s' "$ASR_ZIP")
  if [[ "$actual_size" == "$ASR_SIZE" ]]; then
    echo "[$(date -Is)] ASR_ALREADY_OK size=$actual_size"
  else
    echo "[$(date -Is)] ASR_INVALID_EXISTING size=$actual_size" >&2
    mv "$ASR_ZIP" "$ASR_ZIP.invalid.$(date +%Y%m%d_%H%M%S)"
  fi
fi

if [[ ! -f "$ASR_ZIP" ]]; then
  echo "[$(date -Is)] START asr.zip"
  curl -L --fail --retry 20 --retry-delay 10 -C - \
    -o "$ASR_PART" "$ASR_URL"
  actual_size=$(stat -c '%s' "$ASR_PART")
  if [[ "$actual_size" != "$ASR_SIZE" ]]; then
    echo "[$(date -Is)] SIZE_FAIL size=$actual_size expected=$ASR_SIZE" >&2
    exit 1
  fi
  mv "$ASR_PART" "$ASR_ZIP"
  echo "[$(date -Is)] DONE asr.zip size=$actual_size"
fi

unzip -t "$ASR_ZIP" >/dev/null
sha256sum "$ASR_ZIP" > "$MODELS/asr.zip.sha256"

if [[ ! -d "$MODELS/exp/asr" ]]; then
  unzip -q "$ASR_ZIP" -d "$MODELS"
fi

echo "[$(date -Is)] ASR_ASSET_COMPLETE"
