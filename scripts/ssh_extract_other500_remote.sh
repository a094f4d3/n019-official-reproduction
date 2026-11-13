#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/hpc/activate_n019_official.sh" >/dev/null
ACCOUNT=$(id -un)
BASE="$N019_OFFICIAL_DATA/corpora/libritts"
ARCHIVE="$BASE/train-other-500.tar.gz"
CANONICAL="$BASE/LibriTTS/train-other-500"
AUDIT="$ROOT/audit"
STAMP=$(date +%Y%m%d_%H%M%S)
STAGE="$BASE/.train-other-500.ssh-extract.$STAMP"
LOG="$AUDIT/train-other-500.ssh-extract.$STAMP.log"
COMPLETE="$AUDIT/train-other-500.ssh-complete.$STAMP.txt"
LOCK="$AUDIT/train-other-500.ssh-extract.lock"
EXPECTED_WAV=205044

mkdir -p "$AUDIT"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "Another other-500 extraction lock exists: $LOCK" >&2
  exit 3
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

test -s "$ARCHIVE"
test "$(stat -c %s "$ARCHIVE")" = "44565031479"
mkdir -p "$STAGE"

exec > >(tee -a "$LOG") 2>&1
echo "SSH_EXTRACT_START account=$ACCOUNT host=$(hostname) date=$(date -Is)"
echo "archive=$ARCHIVE"
echo "stage=$STAGE"

pigz -dc -p 16 "$ARCHIVE" \
  | tar -xf - -C "$STAGE" \
      --checkpoint=10000 \
      --checkpoint-action=echo

test -d "$STAGE/LibriTTS/train-other-500"
extracted=$(find "$STAGE/LibriTTS/train-other-500" \
  -type f -name '*.wav' | wc -l)
echo "COUNTS expected=$EXPECTED_WAV extracted=$extracted"
test "$extracted" = "$EXPECTED_WAV"

if [[ -e "$CANONICAL" ]]; then
  mv "$CANONICAL" "$CANONICAL.partial.ssh.$STAMP"
fi
mv "$STAGE/LibriTTS/train-other-500" "$CANONICAL"
rmdir "$STAGE/LibriTTS" 2>/dev/null || true
rmdir "$STAGE" 2>/dev/null || true

{
  echo "archive=$ARCHIVE"
  echo "target=$CANONICAL"
  echo "expected_wav=$EXPECTED_WAV"
  echo "extracted_wav=$extracted"
  echo "completed_at=$(date -Is)"
} > "$COMPLETE"

echo "SSH_EXTRACT_COMPLETE wav=$extracted date=$(date -Is)"
