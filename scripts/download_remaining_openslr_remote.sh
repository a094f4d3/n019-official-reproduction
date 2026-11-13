#!/usr/bin/env bash

set -euo pipefail

DATA="$HOME/voice_projects/data/n019_official/corpora"
ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
PYTHON="$HOME/voice_projects/envs/n019/bin/python"
mkdir -p "$DATA/librispeech" "$DATA/libritts" "$LOGS"

if [[ -f "$LOGS/openslr_download.pid" ]]; then
  old_pid=$(cat "$LOGS/openslr_download.pid")
  pkill -TERM -P "$old_pid" 2>/dev/null || true
  kill -TERM "$old_pid" 2>/dev/null || true
fi

"$PYTHON" "$ROOT/scripts/parallel_download_openslr.py" \
  --url "https://openslr.trmal.net/resources/12/train-clean-360.tar.gz" \
  --output "$DATA/librispeech/train-clean-360.tar.gz" \
  --expected-md5 "c0e676e450a7ff2f54aeade5171606fa" \
  --connections 16

"$PYTHON" "$ROOT/scripts/parallel_download_openslr.py" \
  --url "https://openslr.trmal.net/resources/60/train-other-500.tar.gz" \
  --output "$DATA/libritts/train-other-500.tar.gz" \
  --expected-md5 "7b181dd5ace343a5f38427999684aa6f" \
  --connections 16

echo "OPENSLR_REMAINING_COMPLETE"
