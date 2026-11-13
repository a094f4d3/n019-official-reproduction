#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

if [[ -f "$LOGS/mos_download.pid" ]] \
  && kill -0 "$(cat "$LOGS/mos_download.pid")" 2>/dev/null; then
  echo "mos download already running: $(cat "$LOGS/mos_download.pid")"
  exit 0
fi

nohup bash "$ROOT/scripts/download_mos_repositories_remote.sh" \
  > "$LOGS/mos_download.log" 2>&1 &
echo $! > "$LOGS/mos_download.pid"
echo "mos_download_pid=$(cat "$LOGS/mos_download.pid")"
