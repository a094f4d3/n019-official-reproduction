#!/usr/bin/env bash

set -u

DATA="$HOME/voice_projects/data/n019_official"
STAGING="$DATA/rebuilt/VPC2024_LibriSpeech_rebuilt_v1"

echo "---PROCESSES---"
ps -eo pid,ppid,stat,etime,cmd \
  | grep -E 'finalize_rebuild|package_rebuilt|[t]ar -I|[z]std' \
  | grep -v grep || true

echo "---REBUILT---"
ls -lah "$DATA/rebuilt"

echo "---STAGING---"
find "$STAGING/data" -maxdepth 1 -mindepth 1 -printf '%f %y\n' 2>/dev/null \
  | sort
echo "wav_count=$(find "$STAGING/data" -type f -name '*.wav' 2>/dev/null | wc -l)"
echo "file_count=$(find "$STAGING" -type f 2>/dev/null | wc -l)"
timeout 20s du -sh "$STAGING" 2>/dev/null || true

echo "---SHA_SUM_HEAD---"
head -5 "$STAGING/SHA256SUMS" 2>/dev/null || true
echo "---FINALIZE_LOG---"
cat "$HOME/voice_projects/logs/n019_official/finalize_rebuild.log" 2>/dev/null \
  | tail -120
