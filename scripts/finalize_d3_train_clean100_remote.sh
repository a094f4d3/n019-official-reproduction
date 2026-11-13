#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh" >/dev/null

CANONICAL="$N019_OFFICIAL_DATA/corpora/libritts/LibriTTS/train-clean-100"
RECORDS="$N019_OFFICIAL_DATA/processed/units/libritts_train_clean_100/unit_records.jsonl"
CODEBOOK="$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_100/kmeans_k200_seed20261102.npz"
OLD_ROOT="/public/home/a094f4d4/voice_projects/data/n019_official"
NEW_ROOT="$N019_OFFICIAL_DATA"
AUDIT="$ROOT/audit"
EXPECTED_WAV=33236
EXPECTED_RECORDS=33236
EXPECTED_SPEAKERS=247
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$RECORDS.pre-relocate.$STAMP.jsonl"
COMPLETE="$AUDIT/train-clean-100.relocate-complete.$STAMP.txt"
LOCK="$AUDIT/train-clean-100.relocate.lock"

mkdir -p "$AUDIT"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "Another relocation lock exists: $LOCK" >&2
  exit 3
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

if [[ ! -f "$RECORDS" ]]; then
  echo "Missing unit records: $RECORDS" >&2
  exit 4
fi
if [[ ! -f "$CODEBOOK" ]]; then
  echo "Missing codebook: $CODEBOOK" >&2
  exit 5
fi

wav_count="$(find "$CANONICAL" -type f -name '*.wav' 2>/dev/null | wc -l)"
if [[ "$wav_count" -ne "$EXPECTED_WAV" ]]; then
  echo "train-clean-100 is not ready: wav=$wav_count expected=$EXPECTED_WAV" >&2
  exit 6
fi

record_count="$(wc -l < "$RECORDS")"
test "$record_count" -eq "$EXPECTED_RECORDS"
if grep -q '"/public/home/a094f4d4/voice_projects/data/n019_official' "$RECORDS"; then
  cp -p -- "$RECORDS" "$BACKUP"
  sha256sum "$BACKUP" > "$BACKUP.sha256"
  python "$ROOT/scripts/relocate_unit_records.py" \
    --records "$RECORDS" \
    --old-root "$OLD_ROOT" \
    --new-root "$NEW_ROOT"
elif grep -q '"/public/home/a094f4d3/voice_projects/data/n019_official' "$RECORDS"; then
  echo "UNIT_RECORDS_ALREADY_RELOCATED $RECORDS"
else
  echo "Unit records contain neither d3 nor d4 canonical paths" >&2
  exit 7
fi

python "$ROOT/scripts/verify_unit_dataset.py" \
  --manifest "$N019_OFFICIAL_DATA/processed/manifests/libritts_train_clean_100.jsonl" \
  --unit-records "$RECORDS" \
  --codebook "$CODEBOOK" \
  --expected-records "$EXPECTED_RECORDS" \
  --expected-speakers "$EXPECTED_SPEAKERS" \
  --out "$AUDIT/train-clean-100.relocated-verification.$STAMP.json"

{
  echo "completed_at=$(date -Is)"
  echo "canonical=$CANONICAL"
  echo "wav=$wav_count"
  echo "records=$record_count"
  echo "backup=$BACKUP"
  echo "relocated_sha256=$(sha256sum "$RECORDS" | awk '{print $1}')"
  echo "verification=$AUDIT/train-clean-100.relocated-verification.$STAMP.json"
} > "$COMPLETE"

echo "TRAIN_CLEAN_100_RELOCATE_COMPLETE records=$record_count"
