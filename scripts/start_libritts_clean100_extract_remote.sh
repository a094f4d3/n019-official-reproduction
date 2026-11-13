#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

if [[ -f "$LOGS/libritts_clean100_extract.pid" ]] \
  && kill -0 "$(cat "$LOGS/libritts_clean100_extract.pid")" 2>/dev/null; then
  echo "LibriTTS clean-100 extraction already running"
  exit 0
fi

nohup bash "$ROOT/scripts/extract_libritts_clean100_parallel_remote.sh" \
  > "$LOGS/libritts_clean100_extract.log" 2>&1 &
echo $! > "$LOGS/libritts_clean100_extract.pid"
echo "libritts_clean100_pid=$(cat "$LOGS/libritts_clean100_extract.pid")"
