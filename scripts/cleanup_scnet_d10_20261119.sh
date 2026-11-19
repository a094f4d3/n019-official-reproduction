#!/usr/bin/env bash

set -euo pipefail

VOICE_ROOT=/public/home/a094f4d10/voice_projects
RUNS="$VOICE_ROOT/runs/n019_official"
DATA="$VOICE_ROOT/data/n019_official"
TMP="$VOICE_ROOT/tmp"
OUT="$RUNS/cleanup_20261119_softcap075"

mkdir -p "$OUT"
exec > >(tee -a "$OUT/cleanup.log") 2>&1

echo "cleanup_start=$(date -Is) host=$(hostname) user=$(id -un)"

# Rejected or empty root-owned outputs from failed AI experiments.
rm -rf "$RUNS/spkuniform_bundle_screen_20261119"
rm -f "$RUNS/duration_ecapa_layer9_20261117.log"
rm -rf "$DATA/vpc_ai/data/libri_test_asr_n019_layer9_ecapa_layer9dur_20261117"
rm -rf "$DATA/vpc_ai/data/libri_test_asr_n019_du_nt_nt_utt_20261117"
rm -rf "$DATA/vpc_ai/data/libri_test_asr_n019_layer9_ecapa_hybrid_20261117"
rm -rf "$TMP/tmpdvwa2mdv"

chown -R 666505:666505 "$OUT"

echo "storage_after_cleanup"
df -h /public/home/a094f4d10
du -sh "$RUNS" "$DATA" 2>/dev/null || true

echo "root_owned_remaining"
find "$RUNS" "$DATA" "$TMP" -maxdepth 3 -user root -printf '%y %p\n' \
  2>/dev/null || true

echo "preserved_asset_checks"
sha256sum -c "$RUNS/CURRENT_GOOD_ASSETS_20261119.sha256"

echo "cleanup_complete=$(date -Is)"
