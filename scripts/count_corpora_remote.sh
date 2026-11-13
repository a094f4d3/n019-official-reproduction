#!/usr/bin/env bash

set -u

DATA="$HOME/voice_projects/data/n019_official/corpora"

for path in \
  "$DATA/LibriSpeech/train-clean-100" \
  "$DATA/LibriSpeech/train-clean-360" \
  "$DATA/LibriTTS/train-clean-100" \
  "$DATA/LibriTTS/train-other-500"; do
  echo "---$path"
  if [[ -d "$path" ]]; then
    find "$path" -type f \( -name '*.flac' -o -name '*.wav' \) \
      -printf '.' 2>/dev/null | wc -c
    timeout 15s du -sh "$path" 2>/dev/null || true
  else
    echo "PENDING"
  fi
done
