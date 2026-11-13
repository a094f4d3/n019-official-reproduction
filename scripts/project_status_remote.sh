#!/usr/bin/env bash

set -u

DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"

echo "HOST=$(hostname) DATE=$(date -Is)"
df -h "$HOME" | tail -1

for pair in \
  "parallel_openslr:$LOGS/parallel_openslr.log" \
  "training_extract:$LOGS/training_extract.log" \
  "mos_checkpoints:$LOGS/mos_checkpoints.log"; do
  name=${pair%%:*}
  log=${pair#*:}
  echo "---$name---"
  if [[ -f "$log" ]]; then
    stat -c 'mtime=%y bytes=%s' "$log"
    tail -c 3000 "$log" | tr '\r' '\n' | tail -20
  else
    echo "NO_LOG"
  fi
done

echo "---KEY_SIZES---"
find "$DATA/corpora" "$MODELS/mos" "$DATA/rebuilt" \
  -maxdepth 3 -type f \
  -printf '%p %s\n' 2>/dev/null \
  | sort
