#!/usr/bin/env bash

set -euo pipefail

DEST="/public/home/a094f4d10/voice_projects/data/n019_official/corpora/libritts/LibriTTS/train-clean-100-n019"

for path in \
  /public/home/a094f4d10 \
  /public/home/a094f4d10/voice_projects \
  /public/home/a094f4d10/voice_projects/data \
  /public/home/a094f4d10/voice_projects/data/n019_official \
  /public/home/a094f4d10/voice_projects/data/n019_official/corpora \
  /public/home/a094f4d10/voice_projects/data/n019_official/corpora/libritts \
  /public/home/a094f4d10/voice_projects/data/n019_official/corpora/libritts/LibriTTS \
  "$DEST"; do
  setfacl -m u:a094f4d6:--x "$path"
done

find "$DEST" -type d -exec \
  setfacl -m u:a094f4d6:rwx,m::rwx,d:u:a094f4d6:rwx,d:m::rwx {} +
getfacl -p "$DEST"
