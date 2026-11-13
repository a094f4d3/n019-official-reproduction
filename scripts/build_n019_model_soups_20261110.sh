#!/bin/bash
set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-/public/home/a094f4d7/voice_projects/code/n019_official_diag_20261110}"
PY="${N019_PYTHON:-/public/home/a094f4d7/voice_projects/envs/n019/bin/python}"
SRC="${N019_SOUP_SOURCE_DIR:-/public/home/a094f4d7/voice_projects/tmp/n019_model_soup_20261110}"
OUT="${N019_SOUP_OUT:-/public/home/a094f4d7/voice_projects/tmp/n019_model_soup_candidates_20261110}"
SNAP="${N019_D5_SNAPSHOT_DIR:-/public/home/a094f4d7/voice_projects/tmp/n019_d5_snapshots_20261110}"
AVG="$ROOT/scripts/average_vocoder_checkpoints.py"
if [[ ! -f "$AVG" ]]; then
  AVG="/public/home/a094f4d7/voice_projects/code/n019_official/scripts/average_vocoder_checkpoints.py"
fi

mkdir -p "$SRC" "$OUT"

ln -sfn "$SNAP/generator_step00088000.pt" "$SRC/d5_88.pt"
ln -sfn "$SNAP/generator_step00090000.pt" "$SRC/d5_90.pt"
ln -sfn "$SNAP/generator_step00092000.pt" "$SRC/d5_92.pt"
ln -sfn "$SNAP/generator_step00094000.pt" "$SRC/d5_94.pt"
ln -sfn "$SNAP/generator_step00096000.pt" "$SRC/d5_96.pt"
ln -sfn "$SRC/generator_d5_step00084000.pt" "$SRC/d5_84.pt"
ln -sfn "$SRC/generator_d5_step00086000.pt" "$SRC/d5_86.pt"
ln -sfn "$SRC/generator_d6_step00088000.pt" "$SRC/d6_88.pt"
ln -sfn "$SRC/generator_d6_step00092000.pt" "$SRC/d6_92.pt"

avg() {
  local name="$1"
  shift
  "$PY" "$AVG" --effective-weight-norm "$@" \
    --out "$OUT/generator_avg_soup_${name}.pt"
}

avg interp_88w40_92w60 \
  --checkpoint "$SRC/d5_88.pt" --weight 0.40 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.60

avg interp_88w60_92w40 \
  --checkpoint "$SRC/d5_88.pt" --weight 0.60 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.40

avg triple_84_88_92 \
  --checkpoint "$SRC/d5_84.pt" \
  --checkpoint "$SRC/d5_88.pt" \
  --checkpoint "$SRC/d5_92.pt"

avg triple_86_88_92 \
  --checkpoint "$SRC/d5_86.pt" \
  --checkpoint "$SRC/d5_88.pt" \
  --checkpoint "$SRC/d5_92.pt"

avg triple_88_90_92 \
  --checkpoint "$SRC/d5_88.pt" \
  --checkpoint "$SRC/d5_90.pt" \
  --checkpoint "$SRC/d5_92.pt"

avg triple_88_92_94 \
  --checkpoint "$SRC/d5_88.pt" \
  --checkpoint "$SRC/d5_92.pt" \
  --checkpoint "$SRC/d5_94.pt"

avg quad_84_88_92_96 \
  --checkpoint "$SRC/d5_84.pt" \
  --checkpoint "$SRC/d5_88.pt" \
  --checkpoint "$SRC/d5_92.pt" \
  --checkpoint "$SRC/d5_96.pt"

avg quad_88_90_92_94 \
  --checkpoint "$SRC/d5_88.pt" \
  --checkpoint "$SRC/d5_90.pt" \
  --checkpoint "$SRC/d5_92.pt" \
  --checkpoint "$SRC/d5_94.pt"

"$PY" "$AVG" --effective-weight-norm \
  --allow-nonarchitectural-config-diff \
  --checkpoint "$SRC/d5_88.pt" \
  --checkpoint "$SRC/d5_92.pt" \
  --checkpoint "$SRC/d6_88.pt" \
  --checkpoint "$SRC/d6_92.pt" \
  --out "$OUT/generator_avg_soup_cross_equal_d5d6_88_92.pt"

"$PY" "$AVG" --effective-weight-norm \
  --allow-nonarchitectural-config-diff \
  --checkpoint "$SRC/d5_88.pt" --weight 0.3333333333 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.3333333333 \
  --checkpoint "$SRC/d6_88.pt" --weight 0.1666666667 \
  --checkpoint "$SRC/d6_92.pt" --weight 0.1666666667 \
  --out "$OUT/generator_avg_soup_cross_d5_2_d6_1_88_92.pt"

"$PY" "$AVG" --effective-weight-norm \
  --allow-nonarchitectural-config-diff \
  --checkpoint "$SRC/d5_88.pt" --weight 0.375 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.375 \
  --checkpoint "$SRC/d6_88.pt" --weight 0.125 \
  --checkpoint "$SRC/d6_92.pt" --weight 0.125 \
  --out "$OUT/generator_avg_soup_cross_d5_3_d6_1_88_92.pt"

"$PY" "$AVG" \
  --checkpoint "$SRC/d5_88.pt" \
  --checkpoint "$SRC/d5_92.pt" \
  --out "$OUT/generator_avg_soup_raw_88_92.pt"

sha256sum "$OUT"/*.pt
