#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

if [[ -f "$LOGS/materialize.pid" ]] \
  && kill -0 "$(cat "$LOGS/materialize.pid")" 2>/dev/null; then
  echo "materialize already running: $(cat "$LOGS/materialize.pid")"
  exit 0
fi

nohup bash "$ROOT/scripts/run_materialize_remote.sh" materialize_full 0 8 \
  > "$LOGS/materialize.log" 2>&1 &
echo $! > "$LOGS/materialize.pid"
echo "materialize_pid=$(cat "$LOGS/materialize.pid")"
