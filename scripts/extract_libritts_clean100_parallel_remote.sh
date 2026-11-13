#!/usr/bin/env bash

set -euo pipefail

BASE="$HOME/voice_projects/data/n019_official/corpora/libritts"
ARCHIVE="$BASE/train-clean-100.tar.gz"
TARGET="$BASE/LibriTTS/train-clean-100"

test -f "$ARCHIVE"
actual_md5=$(md5sum "$ARCHIVE" | awk '{print $1}')
test "$actual_md5" = "4a8c202b78fe1bc0c47916a98f3a2ea8"

if [[ ! -d "$TARGET" ]]; then
  nice -n 15 tar -xzf "$ARCHIVE" -C "$BASE"
fi

test -d "$TARGET"
find "$TARGET" -type f -name '*.wav' -printf '.' | wc -c
echo "LIBRITTS_CLEAN100_EXTRACT_OK"
