#!/usr/bin/env bash

set -euo pipefail

SOURCE="/public/home/a094f4d6/voice_projects/data/n019_official/corpora/libritts/LibriTTS/train-clean-100"
DEST="/public/home/a094f4d10/voice_projects/data/n019_official/corpora/libritts/LibriTTS/train-clean-100-n019"

test -d "$SOURCE"
mkdir -p "$DEST"

echo "copy_start=$(date -Is) source=$SOURCE dest=$DEST"
tar -C "$SOURCE" -cf - . | tar -C "$DEST" -xf -
echo "copy_finished=$(date -Is)"
find "$DEST" -type f -name '*.wav' -printf '%s\n' > "$DEST/.wav_sizes"
awk '{bytes += $1; files += 1} END {printf "wav_files=%d wav_bytes=%d\n", files, bytes}' \
  "$DEST/.wav_sizes"
