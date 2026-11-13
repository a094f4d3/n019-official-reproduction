#!/usr/bin/env bash

set -u

DATA="$HOME/voice_projects/data/n019_official/corpora"
LOGS="$HOME/voice_projects/logs/n019_official"

echo "---PROCESSES---"
ps -eo pid,ppid,stat,etime,cmd \
  | grep -E 'parallel_download|download_remaining_openslr' \
  | grep -v grep || true

echo "---PID---"
cat "$LOGS/parallel_openslr.pid" 2>/dev/null || true

echo "---LOG---"
cat "$LOGS/parallel_openslr.log" 2>/dev/null || true

echo "---FILES---"
find "$DATA/librispeech" -maxdepth 1 \
  -name 'train-clean-360*' -printf '%f %s\n' | sort
find "$DATA/libritts" -maxdepth 1 \
  -name 'train-other-500*' -printf '%f %s\n' | sort

echo "---STATE---"
state="$DATA/librispeech/train-clean-360.tar.gz.parallel.state.json"
if [[ -f "$state" ]]; then
  head -80 "$state"
fi
