#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

if [[ -f "$LOGS/other500_stream.pid" ]] \
  && kill -0 "$(cat "$LOGS/other500_stream.pid")" 2>/dev/null; then
  echo "other500 stream extraction already running"
  exit 0
fi

nohup bash "$ROOT/scripts/extract_other500_stream_remote.sh" \
  > "$LOGS/other500_stream.log" 2>&1 &
echo $! > "$LOGS/other500_stream.pid"
echo "other500_stream_pid=$(cat "$LOGS/other500_stream.pid")"
