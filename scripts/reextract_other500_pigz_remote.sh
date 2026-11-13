#!/usr/bin/env bash

set -euo pipefail

BASE="$HOME/voice_projects/data/n019_official/corpora/libritts"
ARCHIVE="$BASE/train-other-500.tar.gz"
TARGET="$BASE/LibriTTS/train-other-500"
LOG="$HOME/voice_projects/logs/n019_official/training_extract.log"
AUDIT="$HOME/voice_projects/code/n019_official/audit"

mkdir -p "$AUDIT"

actual_md5=$(md5sum "$ARCHIVE" | awk '{print $1}')
test "$actual_md5" = "7b181dd5ace343a5f38427999684aa6f"
echo "[$(date -Is)] MD5_OK LibriTTS train-other-500 $actual_md5" >> "$LOG"

if [[ -d "$TARGET" ]]; then
  backup="$TARGET.sequential_partial.$(date +%Y%m%d_%H%M%S)"
  mv "$TARGET" "$backup"
  echo "[$(date -Is)] MOVED_PARTIAL $backup" >> "$LOG"
fi

echo "[$(date -Is)] PIGZ_EXTRACT_START LibriTTS train-other-500" >> "$LOG"
set -o pipefail
nice -n 10 pigz -dc -p 16 "$ARCHIVE" \
  | tar -xf - -C "$BASE"

test -d "$TARGET"
count=$(find "$TARGET" -type f -name '*.wav' -printf '.' | wc -c)
echo "[$(date -Is)] PIGZ_EXTRACT_DONE LibriTTS train-other-500 wav=$count" >> "$LOG"

{
  md5sum \
    "$BASE/../LibriSpeech/train-clean-100.tar.gz" \
    "$BASE/../LibriSpeech/train-clean-360.tar.gz" \
    "$BASE/train-clean-100.tar.gz" \
    "$BASE/train-other-500.tar.gz"
  echo "$count"
} > "$AUDIT/training_corpora.txt"

echo "[$(date -Is)] TRAINING_CORPORA_COMPLETE" >> "$LOG"
echo "OTHER500_PIGZ_EXTRACT_OK wav=$count"
