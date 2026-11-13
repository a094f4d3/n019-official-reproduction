#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d7/voice_projects/code/n019_official
source "$ROOT/hpc/activate_n019_official.sh" >/dev/null
cd "$ROOT"

DATA="$N019_OFFICIAL_DATA/processed"
MANIFEST="$DATA/manifests/libri_test.jsonl"
UNITS="$DATA/units/libri_test_paperfix"
CODEBOOK="$DATA/units/librispeech_train_clean_100/kmeans_k200_seed20261102.npz"
HUBERT="$N019_OFFICIAL_MODELS/hubert"
VERIFY="$ROOT/audit/verify_libri_test_units_paperfix.json"

test "$(wc -l < "$MANIFEST")" = 1934
test "$(sha256sum "$CODEBOOK" | awk '{print $1}')" = \
  a5cc08f707301a1c05da4ab4b00cd280dec66533796a976c3ac4743287eaf446
test -f "$HUBERT/config.json"

mkdir -p "$UNITS"
python -u -m n019.units \
  --manifest "$MANIFEST" \
  --out "$UNITS" \
  --hubert-model "$HUBERT" \
  --codebook "$CODEBOOK" \
  --layer 6 \
  --k 200 \
  --seed 20261102 \
  --batch-size 16 \
  --workers 4 \
  --device cuda

python "$ROOT/scripts/verify_unit_dataset.py" \
  --manifest "$MANIFEST" \
  --unit-records "$UNITS/unit_records.jsonl" \
  --codebook "$CODEBOOK" \
  --expected-records 1934 \
  --expected-speakers 40 \
  --workers 8 \
  --out "$VERIFY"

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
chown -R "$owner" "$UNITS" "$VERIFY"

sha256sum "$MANIFEST" "$CODEBOOK" \
  "$UNITS/unit_records.jsonl" \
  "$UNITS/units_metadata.json" \
  "$VERIFY"
echo LIBRI_TEST_UNITS_PAPERFIX_COMPLETE
