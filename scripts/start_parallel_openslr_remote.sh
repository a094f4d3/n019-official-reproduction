#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

if [[ -f "$LOGS/parallel_openslr.pid" ]] \
  && kill -0 "$(cat "$LOGS/parallel_openslr.pid")" 2>/dev/null; then
  echo "parallel OpenSLR already running: $(cat "$LOGS/parallel_openslr.pid")"
  exit 0
fi

nohup bash "$ROOT/scripts/download_remaining_openslr_remote.sh" \
  > "$LOGS/parallel_openslr.log" 2>&1 &
echo $! > "$LOGS/parallel_openslr.pid"
echo "parallel_openslr_pid=$(cat "$LOGS/parallel_openslr.pid")"
