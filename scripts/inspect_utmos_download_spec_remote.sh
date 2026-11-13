#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"

echo "---DOWNLOAD_SCRIPT---"
sed -n '1,160p' \
  "$ROOT/vendor/UTMOS22/fairseq_checkpoints/download_strong_checkpoints.sh"

echo "---STRONG_README---"
sed -n '1,220p' "$ROOT/vendor/UTMOS22/strong/README.md"

echo "---PREDICT---"
sed -n '1,180p' "$ROOT/vendor/UTMOS22/strong/predict.py"
