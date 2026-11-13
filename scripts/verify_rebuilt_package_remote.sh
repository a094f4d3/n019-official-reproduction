#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
BUILD_ID="VPC2024_LibriSpeech_rebuilt_v1"
ARCHIVE="$DATA/rebuilt/$BUILD_ID.tar.zst"
AUDIT="$ROOT/audit"
mkdir -p "$AUDIT"

sha256sum -c "$ARCHIVE.sha256"
tar -I zstd -tf "$ARCHIVE" > "$AUDIT/package_file_list.txt"

wav_entries=$(grep -c '\.wav$' "$AUDIT/package_file_list.txt")
test "$wav_entries" = "4255"
grep -q "$BUILD_ID/audit/build_id.txt" "$AUDIT/package_file_list.txt"
grep -q "$BUILD_ID/SHA256SUMS" "$AUDIT/package_file_list.txt"

tmp=$(mktemp -d "$DATA/rebuilt/.verify.$BUILD_ID.XXXXXX")
cleanup() {
  case "$tmp" in
    "$DATA/rebuilt/.verify.$BUILD_ID."*)
      rm -rf -- "$tmp"
      ;;
  esac
}
trap cleanup EXIT

tar -I zstd -xf "$ARCHIVE" -C "$tmp"
(
  cd "$tmp/$BUILD_ID"
  sha256sum -c SHA256SUMS >/dev/null
  test "$(find data -type f -name '*.wav' | wc -l)" = "4255"
  test "$(cat audit/build_id.txt)" = "$BUILD_ID"
)

{
  sha256sum "$ARCHIVE"
  echo "wav_entries=$wav_entries"
  echo "sha256sums_verified=4255"
  echo "build_id=$BUILD_ID"
} | tee "$AUDIT/package_verification.txt"

echo "REBUILT_PACKAGE_VERIFIED"
