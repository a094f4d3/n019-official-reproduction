#!/bin/bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SNAP_DIR="$N019_OFFICIAL_RUNS/vocoder_nt_layer9_aligned_pilot_20261116/snapshots"
python scripts/audit_vocoder_snapshots.py \
  --snapshots \
    "$SNAP_DIR/generator_step00008000.pt" \
    "$SNAP_DIR/generator_step00010000.pt" \
    "$SNAP_DIR/generator_step00012000.pt" \
    "$SNAP_DIR/generator_step00014000.pt" \
    "$SNAP_DIR/generator_step00016000.pt" \
  --out "$N019_OFFICIAL_RUNS/audit/layer9_snapshot_audit_20261117.json"
