#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
OUTPUT="$ROOT/audit/n019_primary_audit_20261102.tar.gz"

tar -czf "$OUTPUT" \
  -C "$ROOT/audit" \
  PRIMARY_SETUP_STATUS \
  asset_manifest.tsv \
  mos_assets.tsv \
  cpu_probe.json \
  package_verification.txt \
  materialize_full/verification.json \
  environment.txt \
  unit_tests.txt \
  source_tree_sha256.txt \
  -C "$LOGS" \
  parallel_openslr.log \
  training_extract.log

sha256sum "$OUTPUT"
