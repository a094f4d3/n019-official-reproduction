#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"

echo "---WHISQA_CHECKPOINT---"
if [[ -f "$ROOT/vendor/WhiSQA/checkpoints/single_head_model.pt" ]]; then
  stat -c '%n %s bytes' "$ROOT/vendor/WhiSQA/checkpoints/single_head_model.pt"
  file "$ROOT/vendor/WhiSQA/checkpoints/single_head_model.pt"
  head -c 200 "$ROOT/vendor/WhiSQA/checkpoints/single_head_model.pt" \
    | strings
else
  echo "MISSING"
fi

echo "---WHISQA_FILES---"
find "$ROOT/vendor/WhiSQA" -maxdepth 2 -type f \
  -printf '%p %s\n' | sort | head -100

echo "---UTMOS_README---"
grep -n -A 12 -B 8 -E 'strong|learner|checkpoint|Space|demo' \
  "$ROOT/vendor/UTMOS22/README.md" | head -240

echo "---UTMOS_FILES---"
find "$ROOT/vendor/UTMOS22" -maxdepth 3 -type f \
  -printf '%p %s\n' | sort | head -150
