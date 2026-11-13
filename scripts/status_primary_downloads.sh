#!/usr/bin/env bash

set -u

LOGS="$HOME/voice_projects/logs/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official/vpc"

for name in \
  asr_download \
  openslr_download \
  materialize \
  parallel_openslr \
  mos_download \
  mos_checkpoints \
  training_extract; do
  echo "---$name---"
  if [[ -f "$LOGS/$name.pid" ]]; then
    pid=$(cat "$LOGS/$name.pid")
    echo "PID=$pid"
    if kill -0 "$pid" 2>/dev/null; then
      echo "STATE=RUNNING"
    else
      echo "STATE=STOPPED"
    fi
  else
    echo "PID_FILE_MISSING"
  fi
  tail -c 4000 "$LOGS/$name.log" 2>/dev/null \
    | tr '\r' '\n' \
    | tail -20 || true
done

echo "---FINALIZE---"
pgrep -af finalize_rebuild_remote.sh || true
pgrep -af package_rebuilt_remote.sh || true
tail -c 5000 "$LOGS/finalize_rebuild.log" 2>/dev/null \
  | tr '\r' '\n' \
  | tail -80 || true

echo "---FILES---"
find "$DATA/corpora" "$MODELS" -maxdepth 3 -type f \
  -printf '%p %s\n' 2>/dev/null | sort

echo "---REBUILT_PACKAGE---"
find "$DATA/rebuilt" -maxdepth 2 -type f -printf '%p %s\n' \
  2>/dev/null | sort
