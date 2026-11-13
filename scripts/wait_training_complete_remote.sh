#!/usr/bin/env bash

set -euo pipefail

LOG="$HOME/voice_projects/logs/n019_official/training_extract.log"

while ! grep -q "TRAINING_CORPORA_COMPLETE" "$LOG" 2>/dev/null; do
  if grep -Eq "MD5_FAIL|tar:.*Error|TRAINING_CORPORA_COMPLETE" \
    "$LOG" 2>/dev/null; then
    tail -80 "$LOG"
    exit 1
  fi
  sleep 60
  echo "waiting $(date -Is)"
done

tail -40 "$LOG"
