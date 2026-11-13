#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

if [[ -f "$LOGS/finalize_rebuild.pid" ]] \
  && kill -0 "$(cat "$LOGS/finalize_rebuild.pid")" 2>/dev/null; then
  echo "finalize already running: $(cat "$LOGS/finalize_rebuild.pid")"
  exit 0
fi

nohup bash "$ROOT/scripts/finalize_rebuild_remote.sh" \
  > "$LOGS/finalize_rebuild.log" 2>&1 &
echo $! > "$LOGS/finalize_rebuild.pid"
echo "finalize_rebuild_pid=$(cat "$LOGS/finalize_rebuild.pid")"
