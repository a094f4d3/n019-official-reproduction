#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

ARCHIVE="$N019_OFFICIAL_DATA/corpora/librispeech/train-clean-360.tar.gz"
DEST="$N019_OFFICIAL_DATA/corpora/librispeech"
LS360="$DEST/LibriSpeech/train-clean-360"
AUDIT="$ROOT/audit"
EXPECTED_MD5="c0e676e450a7ff2f54aeade5171606fa"

if [[ ! -f "$ARCHIVE" ]]; then
  echo "Missing archive: $ARCHIVE" >&2
  exit 1
fi
ACTUAL_MD5=$(md5sum "$ARCHIVE" | awk '{print $1}')
if [[ "$ACTUAL_MD5" != "$EXPECTED_MD5" ]]; then
  echo "Archive MD5 mismatch: $ACTUAL_MD5" >&2
  exit 1
fi

mkdir -p "$DEST" "$AUDIT"
echo "extract_begin account=$(id -un) host=$(hostname) date=$(date -Is)"
echo "archive=$ARCHIVE dest=$DEST"

if [[ -d "$LS360" ]]; then
  EXISTING=$(find "$LS360" -type f -name '*.flac' | wc -l)
else
  EXISTING=0
fi
if [[ "$EXISTING" != "104014" ]]; then
  tar -xzf "$ARCHIVE" -C "$DEST"
fi

FILES=$(find "$LS360" -type f -name '*.flac' | wc -l)
SPEAKERS=$(find "$LS360" -mindepth 1 -maxdepth 1 -type d | wc -l)
if [[ "$FILES" != "104014" ]]; then
  echo "Expected 104014 FLAC files, got $FILES" >&2
  exit 1
fi
if [[ "$SPEAKERS" != "921" ]]; then
  echo "Expected 921 speaker directories, got $SPEAKERS" >&2
  exit 1
fi

{
  echo "account=$(id -un)"
  echo "host=$(hostname)"
  echo "date=$(date -Is)"
  echo "archive=$ARCHIVE"
  echo "archive_md5=$ACTUAL_MD5"
  echo "ls360=$LS360"
  echo "flac_files=$FILES"
  echo "speaker_directories=$SPEAKERS"
} | tee "$AUDIT/ls360_extract_complete_$(date +%Y%m%d_%H%M%S).txt"

echo "LS360_EXTRACT_COMPLETE files=$FILES speakers=$SPEAKERS"
