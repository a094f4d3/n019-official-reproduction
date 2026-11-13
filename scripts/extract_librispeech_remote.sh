#!/usr/bin/env bash

set -euo pipefail

BASE="$HOME/voice_projects/data/n019_official/corpora/librispeech"
AUDIT="$HOME/voice_projects/code/n019_official/audit"
mkdir -p "$BASE" "$AUDIT"

check_archive() {
  local path=$1
  local expected_md5=$2
  local label=$3
  test -f "$path"
  actual_md5=$(md5sum "$path" | awk '{print $1}')
  if [[ "$actual_md5" != "$expected_md5" ]]; then
    echo "MD5_FAIL $label actual=$actual_md5 expected=$expected_md5" >&2
    exit 1
  fi
  echo "MD5_OK $label $actual_md5"
}

check_archive \
  "$BASE/test-clean.tar.gz" \
  "32fa31d27d2e1cad72775fee3f4849a9" \
  "LibriSpeech test-clean"
check_archive \
  "$BASE/dev-clean.tar.gz" \
  "42e2234ba48799c1f50f24a7926300a1" \
  "LibriSpeech dev-clean"

if [[ ! -d "$BASE/LibriSpeech/test-clean" ]]; then
  tar -xzf "$BASE/test-clean.tar.gz" -C "$BASE"
fi
if [[ ! -d "$BASE/LibriSpeech/dev-clean" ]]; then
  tar -xzf "$BASE/dev-clean.tar.gz" -C "$BASE"
fi

test -d "$BASE/LibriSpeech/test-clean"
test -d "$BASE/LibriSpeech/dev-clean"

{
  md5sum "$BASE/test-clean.tar.gz" "$BASE/dev-clean.tar.gz"
  find "$BASE/LibriSpeech/test-clean" -type f -name '*.flac' | wc -l
  find "$BASE/LibriSpeech/dev-clean" -type f -name '*.flac' | wc -l
} > "$AUDIT/librispeech_dev_test_extract.txt"

echo "LIBRISPEECH_DEV_TEST_EXTRACT_OK"
