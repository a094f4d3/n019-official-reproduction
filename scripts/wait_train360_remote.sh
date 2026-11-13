#!/usr/bin/env bash

set -euo pipefail

DATA="$HOME/voice_projects/data/n019_official/corpora/librispeech"
TARGET="$DATA/train-clean-360.tar.gz"

while [[ ! -f "$TARGET" ]]; do
  sleep 30
  echo "waiting $(date -Is)"
done

stat -c '%n %s bytes' "$TARGET"
md5sum "$TARGET"
