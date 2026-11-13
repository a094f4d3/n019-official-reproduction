#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
OUT="$ROOT/audit/probe_nt_cpu.json"
LOG="$ROOT/audit/probe_nt_cpu.log"
EXIT_FILE="$ROOT/audit/probe_nt_cpu.exit"

cd "$ROOT"
source hpc/activate_n019_official.sh
export PYTHONPATH="$ROOT/compat:$ROOT/src"

set +e
python -u -m n019.probe_models \
  --audio "$DATA/corpora/librispeech/LibriSpeech/test-clean/6930/75918/6930-75918-0006.flac" \
  --hubert "$MODELS/hubert" \
  --speaker-model "$MODELS/wpro" \
  --speaker-kind nt \
  --out "$OUT" \
  --device cpu \
  >"$LOG" 2>&1
status=$?
echo "$status" >"$EXIT_FILE"
exit "$status"
