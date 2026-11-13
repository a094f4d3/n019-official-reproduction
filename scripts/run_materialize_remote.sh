#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
AUDIT_NAME="${1:-materialize_full}"
LIMIT="${2:-0}"
JOBS="${3:-8}"

source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$ROOT/audit/$AUDIT_NAME" "$LOGS"

python "$ROOT/scripts/materialize_vpc2024.py" \
  --vpc-root "$DATA/vpc" \
  --librispeech-root "$DATA/corpora/librispeech/LibriSpeech" \
  --ffmpeg "$(command -v ffmpeg)" \
  --audit-dir "$ROOT/audit/$AUDIT_NAME" \
  --build-id "VPC2024_LibriSpeech_rebuilt_v1" \
  --jobs "$JOBS" \
  --limit "$LIMIT"

echo "MATERIALIZE_OK audit=$ROOT/audit/$AUDIT_NAME"
