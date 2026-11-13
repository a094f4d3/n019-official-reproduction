#!/usr/bin/env bash

set -euo pipefail

DATA="$HOME/voice_projects/data/n019_official/corpora"
AUDIT="$HOME/voice_projects/code/n019_official/audit"
mkdir -p "$AUDIT"

wait_and_extract() {
  local archive=$1
  local expected_md5=$2
  local destination=$3
  local expected_dir=$4
  local label=$5

  while [[ ! -f "$archive" ]]; do
    echo "[$(date -Is)] WAIT $label"
    sleep 60
  done

  local actual_md5
  actual_md5=$(md5sum "$archive" | awk '{print $1}')
  if [[ "$actual_md5" != "$expected_md5" ]]; then
    echo "[$(date -Is)] MD5_FAIL $label $actual_md5 != $expected_md5" >&2
    exit 1
  fi
  echo "[$(date -Is)] MD5_OK $label $actual_md5"

  if [[ ! -d "$expected_dir" ]]; then
    echo "[$(date -Is)] EXTRACT_START $label"
    nice -n 10 tar -xzf "$archive" -C "$destination"
    echo "[$(date -Is)] EXTRACT_DONE $label"
  else
    echo "[$(date -Is)] EXISTS $expected_dir"
  fi
}

wait_and_extract \
  "$DATA/librispeech/train-clean-100.tar.gz" \
  "2a93770f6d5c6c964bc36631d331a522" \
  "$DATA/librispeech" \
  "$DATA/librispeech/LibriSpeech/train-clean-100" \
  "LibriSpeech train-clean-100"

wait_and_extract \
  "$DATA/librispeech/train-clean-360.tar.gz" \
  "c0e676e450a7ff2f54aeade5171606fa" \
  "$DATA/librispeech" \
  "$DATA/librispeech/LibriSpeech/train-clean-360" \
  "LibriSpeech train-clean-360"

wait_and_extract \
  "$DATA/libritts/train-clean-100.tar.gz" \
  "4a8c202b78fe1bc0c47916a98f3a2ea8" \
  "$DATA/libritts" \
  "$DATA/libritts/LibriTTS/train-clean-100" \
  "LibriTTS train-clean-100"

wait_and_extract \
  "$DATA/libritts/train-other-500.tar.gz" \
  "7b181dd5ace343a5f38427999684aa6f" \
  "$DATA/libritts" \
  "$DATA/libritts/LibriTTS/train-other-500" \
  "LibriTTS train-other-500"

{
  md5sum \
    "$DATA/librispeech/train-clean-100.tar.gz" \
    "$DATA/librispeech/train-clean-360.tar.gz" \
    "$DATA/libritts/train-clean-100.tar.gz" \
    "$DATA/libritts/train-other-500.tar.gz"
  find "$DATA/librispeech/LibriSpeech/train-clean-100" -type f -name '*.flac' | wc -l
  find "$DATA/librispeech/LibriSpeech/train-clean-360" -type f -name '*.flac' | wc -l
  find "$DATA/libritts/LibriTTS/train-clean-100" -type f -name '*.wav' | wc -l
  find "$DATA/libritts/LibriTTS/train-other-500" -type f -name '*.wav' | wc -l
} > "$AUDIT/training_corpora.txt"

echo "TRAINING_CORPORA_COMPLETE"
