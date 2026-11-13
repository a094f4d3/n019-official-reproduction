#!/usr/bin/env bash

set -euo pipefail

DATA="$HOME/voice_projects/data/n019_official/corpora"
LOG_DIR="$HOME/voice_projects/logs/n019_official"
mkdir -p "$DATA/librispeech" "$DATA/libritts" "$LOG_DIR"

download_verify() {
  local url=$1
  local output=$2
  local expected_md5=$3
  local label=$4

  echo "[$(date -Is)] START $label"
  if [[ -f "$output" ]]; then
    actual_md5=$(md5sum "$output" | awk '{print $1}')
    if [[ "$actual_md5" == "$expected_md5" ]]; then
      echo "[$(date -Is)] ALREADY_OK $label $actual_md5"
      return 0
    fi
    echo "[$(date -Is)] INVALID_EXISTING $label md5=$actual_md5"
    mv "$output" "$output.invalid.$(date +%Y%m%d_%H%M%S)"
  fi

  wget -c --tries=20 --timeout=60 --waitretry=10 \
    -O "$output.part" "$url"
  actual_md5=$(md5sum "$output.part" | awk '{print $1}')
  if [[ "$actual_md5" != "$expected_md5" ]]; then
    echo "[$(date -Is)] MD5_FAIL $label actual=$actual_md5 expected=$expected_md5" >&2
    exit 1
  fi
  mv "$output.part" "$output"
  echo "[$(date -Is)] DONE $label md5=$actual_md5"
}

download_verify \
  "https://www.openslr.org/resources/12/dev-clean.tar.gz" \
  "$DATA/librispeech/dev-clean.tar.gz" \
  "42e2234ba48799c1f50f24a7926300a1" \
  "LibriSpeech dev-clean"

download_verify \
  "https://www.openslr.org/resources/12/train-clean-100.tar.gz" \
  "$DATA/librispeech/train-clean-100.tar.gz" \
  "2a93770f6d5c6c964bc36631d331a522" \
  "LibriSpeech train-clean-100"

download_verify \
  "https://www.openslr.org/resources/12/train-clean-360.tar.gz" \
  "$DATA/librispeech/train-clean-360.tar.gz" \
  "c0e676e450a7ff2f54aeade5171606fa" \
  "LibriSpeech train-clean-360"

download_verify \
  "https://www.openslr.org/resources/60/train-other-500.tar.gz" \
  "$DATA/libritts/train-other-500.tar.gz" \
  "7b181dd5ace343a5f38427999684aa6f" \
  "LibriTTS train-other-500"

echo "[$(date -Is)] ALL_OPENSLR_DOWNLOADS_COMPLETE"
