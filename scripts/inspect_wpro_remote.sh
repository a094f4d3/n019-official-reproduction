#!/usr/bin/env bash

set -euo pipefail

MODEL="$HOME/voice_projects/models/n019_official/wpro"
OLD="$HOME/voice_projects/code/n019_repro"

echo "---WPRO_SCRIPT---"
sed -n '1,220p' "$MODEL/spk_embeddings.py"

echo "---WPRO_README_USAGE---"
grep -n -A 30 -B 5 -E 'usage|Usage|WavLM|extract' \
  "$MODEL/README.md" | head -160

echo "---OLD_CODE_REFERENCES---"
grep -RIn -E 'spk_embeddings|Speaker-wavLM|wpro' "$OLD/src" \
  "$OLD/tests" 2>/dev/null | head -120
