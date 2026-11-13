#!/usr/bin/env bash

set -euo pipefail
ulimit -f unlimited 2>/dev/null || true

BASE="$HOME/voice_projects/data/n019_official/corpora/libritts"
ARCHIVE="$BASE/train-other-500.tar.gz"
TARGET="$BASE/LibriTTS/train-other-500"
LOG="$HOME/voice_projects/logs/n019_official/training_extract.log"
AUDIT="$HOME/voice_projects/code/n019_official/audit"
PYTHON="$HOME/voice_projects/envs/n019/bin/python"
ROOT="$HOME/voice_projects/code/n019_official"

test "$(stat -c '%s' "$ARCHIVE")" = "44565031479"
grep -q '"md5": "7b181dd5ace343a5f38427999684aa6f"' \
  "$HOME/voice_projects/logs/n019_official/parallel_openslr.log"

if [[ -d "$TARGET" ]]; then
  backup="$TARGET.stream_previous.$(date +%Y%m%d_%H%M%S)"
  mv "$TARGET" "$backup"
  echo "[$(date -Is)] MOVED_STREAM_PREVIOUS $backup" >> "$LOG"
fi

echo "[$(date -Is)] STREAM_EXTRACT_START LibriTTS train-other-500" >> "$LOG"
"$PYTHON" "$ROOT/scripts/stream_extract_tar.py" \
  --archive "$ARCHIVE" \
  --dest "$BASE" \
  --workers 24 \
  --pending 256

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
echo "OTHER500_STREAM_EXTRACT_OK wav=$count"
