#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"

source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

AUDIO="$DATA/vpc/data/libri_test/wav/1089-134686-0002.wav"
test -s "$AUDIO"

python -u -m n019.probe_models \
  --audio "$AUDIO" \
  --out "$ROOT/audit/cpu_probe.json" \
  --models "$MODELS" \
  --hubert-layer 6 \
  --kmeans-k 200 \
  --device cpu

cat "$ROOT/audit/cpu_probe.json"
