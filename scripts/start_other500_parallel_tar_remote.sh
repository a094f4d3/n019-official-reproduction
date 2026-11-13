#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

if [[ -f "$LOGS/other500_parallel.pid" ]] \
  && kill -0 "$(cat "$LOGS/other500_parallel.pid")" 2>/dev/null; then
  echo "other500 parallel extraction already running"
  exit 0
fi

nohup bash "$ROOT/scripts/extract_other500_parallel_tar_remote.sh" \
  > "$LOGS/other500_parallel.log" 2>&1 &
echo $! > "$LOGS/other500_parallel.pid"
echo "other500_parallel_pid=$(cat "$LOGS/other500_parallel.pid")"
