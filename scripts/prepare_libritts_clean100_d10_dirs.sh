#!/usr/bin/env bash

set -euo pipefail

SOURCE="/public/home/a094f4d6/voice_projects/data/n019_official/corpora/libritts/LibriTTS/train-clean-100"
DEST="/public/home/a094f4d10/voice_projects/data/n019_official/corpora/libritts/LibriTTS/train-clean-100-n019"

test -d "$SOURCE"
mkdir -p "$DEST"

cd "$SOURCE"
find . -type d -exec mkdir -p "$DEST/{}" \;
find "$DEST" -type d -exec chmod 777 {} +

echo "directories_prepared=$(date -Is)"
find "$DEST" -type d -printf 'dir %p %m\n' | tail -n 5
