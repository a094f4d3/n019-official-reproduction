#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

if [[ -f "$LOGS/training_extract.pid" ]] \
  && kill -0 "$(cat "$LOGS/training_extract.pid")" 2>/dev/null; then
  echo "training extraction already running: $(cat "$LOGS/training_extract.pid")"
  exit 0
fi

nohup bash "$ROOT/scripts/extract_training_corpora_remote.sh" \
  > "$LOGS/training_extract.log" 2>&1 &
echo $! > "$LOGS/training_extract.pid"
echo "training_extract_pid=$(cat "$LOGS/training_extract.pid")"
