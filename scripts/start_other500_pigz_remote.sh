#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

if [[ -f "$LOGS/other500_pigz.pid" ]] \
  && kill -0 "$(cat "$LOGS/other500_pigz.pid")" 2>/dev/null; then
  echo "other500 pigz extraction already running"
  exit 0
fi

nohup bash "$ROOT/scripts/reextract_other500_pigz_remote.sh" \
  > "$LOGS/other500_pigz.log" 2>&1 &
echo $! > "$LOGS/other500_pigz.pid"
echo "other500_pigz_pid=$(cat "$LOGS/other500_pigz.pid")"
