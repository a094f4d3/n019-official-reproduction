#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"

cd "$ROOT"

if [[ -f bootstrap_assets.tar.gz ]]; then
  tar -xzf bootstrap_assets.tar.gz -C "$ROOT"
fi

chmod +x "$ROOT/scripts/"*.sh 2>/dev/null || true

cp -f "$ROOT/vendor/vpc2024/data.zip" "$DATA/vpc/data.zip"
cp -f "$ROOT/vendor/vpc2024/data_test_tools.zip" "$DATA/vpc/data_test_tools.zip"
cp -f "$ROOT/vendor/vpc2024/asv_orig.zip" "$MODELS/vpc/asv_orig.zip"

for archive in \
  "$DATA/vpc/data.zip" \
  "$DATA/vpc/data_test_tools.zip" \
  "$MODELS/vpc/asv_orig.zip"; do
  test -s "$archive"
  unzip -t "$archive" >/dev/null
done

if [[ ! -d "$DATA/vpc/data" ]]; then
  unzip -oq "$DATA/vpc/data.zip" -d "$DATA/vpc"
fi

if [[ ! -d "$DATA/vpc/data_test_tools" ]]; then
  unzip -oq "$DATA/vpc/data_test_tools.zip" -d "$DATA/vpc"
fi

if [[ ! -d "$MODELS/vpc/exp/asv_orig" ]]; then
  unzip -oq "$MODELS/vpc/asv_orig.zip" -d "$MODELS/vpc"
fi

test "$(git -C "$ROOT/vendor/Voice-Privacy-Challenge-2024" rev-parse HEAD)" \
  = "7c80e86d3a4d58b81a2f3bdc01a3508c37018be4"

test "$(wc -l < "$DATA/vpc/data/libri_test_enrolls/wav.scp")" = "438"
test "$(wc -l < "$DATA/vpc/data/libri_test_trials_f/wav.scp")" = "734"
test "$(wc -l < "$DATA/vpc/data/libri_test_trials_f/trials")" = "11744"
test "$(wc -l < "$DATA/vpc/data/libri_test_trials_m/wav.scp")" = "762"
test "$(wc -l < "$DATA/vpc/data/libri_test_trials_m/trials")" = "9906"

sha256sum \
  "$DATA/vpc/data.zip" \
  "$DATA/vpc/data_test_tools.zip" \
  "$MODELS/vpc/asv_orig.zip" \
  > "$ROOT/audit/bootstrap_zip_sha256.txt"

echo "VPC_BOOTSTRAP_OK"
