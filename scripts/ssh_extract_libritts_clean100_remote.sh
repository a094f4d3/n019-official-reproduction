#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/hpc/activate_n019_official.sh" >/dev/null

BASE="$N019_OFFICIAL_DATA/corpora/libritts"
ARCHIVE="$BASE/train-clean-100.tar.gz"
CANONICAL="$BASE/LibriTTS/train-clean-100"
AUDIT="$ROOT/audit"
EXPECTED_MD5="4a8c202b78fe1bc0c47916a98f3a2ea8"
EXPECTED_WAV=33236
STAMP="$(date +%Y%m%d_%H%M%S)"
STAGE="$BASE/.train-clean-100.ssh-extract.$STAMP"
LOG="$AUDIT/train-clean-100.ssh-extract.$STAMP.log"
COMPLETE="$AUDIT/train-clean-100.ssh-complete.$STAMP.txt"
LOCK="$AUDIT/train-clean-100.ssh-extract.lock"

mkdir -p "$AUDIT" "$BASE/LibriTTS"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "Another train-clean-100 extraction lock exists: $LOCK" >&2
  exit 3
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

if [[ -d "$CANONICAL" ]]; then
  count="$(find "$CANONICAL" -type f -name '*.wav' | wc -l)"
  test "$count" -eq "$EXPECTED_WAV"
  echo "ALREADY_COMPLETE target=$CANONICAL wav=$count"
  exit 0
fi

test -s "$ARCHIVE"
actual_md5="$(md5sum "$ARCHIVE" | awk '{print $1}')"
test "$actual_md5" = "$EXPECTED_MD5"
mkdir -p "$STAGE"

exec > >(tee -a "$LOG") 2>&1
echo "SSH_EXTRACT_START account=$(id -un) host=$(hostname) date=$(date -Is)"
echo "archive=$ARCHIVE md5=$actual_md5"
echo "stage=$STAGE"

pigz -dc -p 16 "$ARCHIVE" \
  | tar -xf - -C "$STAGE" \
      --checkpoint=10000 \
      --checkpoint-action=echo

test -d "$STAGE/LibriTTS/train-clean-100"
extracted="$(find "$STAGE/LibriTTS/train-clean-100" -type f -name '*.wav' | wc -l)"
echo "COUNTS expected=$EXPECTED_WAV extracted=$extracted"
test "$extracted" -eq "$EXPECTED_WAV"

if [[ -e "$CANONICAL" ]]; then
  echo "Refusing to overwrite existing canonical directory: $CANONICAL" >&2
  exit 4
fi
mv -- "$STAGE/LibriTTS/train-clean-100" "$CANONICAL"

{
  echo "archive=$ARCHIVE"
  echo "md5=$actual_md5"
  echo "target=$CANONICAL"
  echo "expected_wav=$EXPECTED_WAV"
  echo "extracted_wav=$extracted"
  echo "completed_at=$(date -Is)"
} > "$COMPLETE"

echo "SSH_EXTRACT_COMPLETE wav=$extracted date=$(date -Is)"
