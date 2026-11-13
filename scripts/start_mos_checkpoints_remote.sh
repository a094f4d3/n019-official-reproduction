#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

if [[ -f "$LOGS/mos_checkpoints.pid" ]] \
  && kill -0 "$(cat "$LOGS/mos_checkpoints.pid")" 2>/dev/null; then
  if [[ "${1:-}" != "force" ]]; then
    echo "MOS checkpoints already running: $(cat "$LOGS/mos_checkpoints.pid")"
    exit 0
  fi
  old_pid=$(cat "$LOGS/mos_checkpoints.pid")
  pkill -TERM -P "$old_pid" 2>/dev/null || true
  kill -TERM "$old_pid" 2>/dev/null || true
  sleep 2
fi

nohup bash "$ROOT/scripts/download_mos_checkpoints_remote.sh" \
  > "$LOGS/mos_checkpoints.log" 2>&1 &
echo $! > "$LOGS/mos_checkpoints.pid"
echo "mos_checkpoints_pid=$(cat "$LOGS/mos_checkpoints.pid")"
