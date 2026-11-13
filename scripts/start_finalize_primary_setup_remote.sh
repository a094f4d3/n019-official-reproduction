#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

if [[ -f "$LOGS/finalize_primary.pid" ]] \
  && kill -0 "$(cat "$LOGS/finalize_primary.pid")" 2>/dev/null; then
  echo "primary finalize already running"
  exit 0
fi

nohup bash "$ROOT/scripts/finalize_primary_setup_remote.sh" \
  > "$LOGS/finalize_primary.log" 2>&1 &
echo $! > "$LOGS/finalize_primary.pid"
echo "finalize_primary_pid=$(cat "$LOGS/finalize_primary.pid")"
