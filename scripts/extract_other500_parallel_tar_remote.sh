#!/usr/bin/env bash

set -euo pipefail
ulimit -f unlimited 2>/dev/null || true

BASE="$HOME/voice_projects/data/n019_official/corpora/libritts"
ARCHIVE="$BASE/train-other-500.tar.gz"
PLAIN="/dev/shm/n019_a094f4d4_train-other-500.tar"
TARGET="$BASE/LibriTTS/train-other-500"
LOG="$HOME/voice_projects/logs/n019_official/training_extract.log"
AUDIT="$HOME/voice_projects/code/n019_official/audit"
PYTHON="$HOME/voice_projects/envs/n019/bin/python"

if [[ -d "$TARGET" ]]; then
  backup="$TARGET.pigz_partial.$(date +%Y%m%d_%H%M%S)"
  mv "$TARGET" "$backup"
  echo "[$(date -Is)] MOVED_PIGZ_PARTIAL $backup" >> "$LOG"
fi

if [[ ! -f "$PLAIN" ]]; then
  echo "[$(date -Is)] DECOMPRESS_START train-other-500.tar" >> "$LOG"
  nice -n 10 pigz -dc -p 16 "$ARCHIVE" > "$PLAIN.part"
  mv "$PLAIN.part" "$PLAIN"
  echo "[$(date -Is)] DECOMPRESS_DONE train-other-500.tar" >> "$LOG"
fi

echo "[$(date -Is)] PARALLEL_EXTRACT_START LibriTTS train-other-500" >> "$LOG"
"$PYTHON" "$HOME/voice_projects/code/n019_official/scripts/parallel_extract_tar.py" \
  --tar "$PLAIN" \
  --dest "$BASE" \
  --workers 16

test -d "$TARGET"
count=$(find "$TARGET" -type f -name '*.wav' -printf '.' | wc -c)
{
  md5sum \
    "$BASE/../LibriSpeech/train-clean-100.tar.gz" \
    "$BASE/../LibriSpeech/train-clean-360.tar.gz" \
    "$BASE/train-clean-100.tar.gz" \
    "$BASE/train-other-500.tar.gz"
  echo "$count"
} > "$AUDIT/training_corpora.txt"
echo "[$(date -Is)] TRAINING_CORPORA_COMPLETE wav=$count" >> "$LOG"
echo "OTHER500_PARALLEL_EXTRACT_OK wav=$count"
