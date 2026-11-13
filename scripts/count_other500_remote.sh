#!/usr/bin/env bash

set -u

TARGET="$HOME/voice_projects/data/n019_official/corpora/LibriTTS/train-other-500"
count=$(find "$TARGET" -type f -name '*.wav' -printf '.' 2>/dev/null | wc -c)
echo "other500_wav_count=$count"
