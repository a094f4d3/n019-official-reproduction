#!/bin/bash
set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-/public/home/a094f4d7/voice_projects/code/n019_official_diag_20261110}"
PY="${N019_PYTHON:-/public/home/a094f4d7/voice_projects/envs/n019/bin/python}"
SRC="${N019_SOUP_SOURCE_DIR:-/public/home/a094f4d7/voice_projects/tmp/n019_model_soup_20261110}"
OUT="${N019_SOUP_OUT:-/public/home/a094f4d7/voice_projects/tmp/n019_model_soup_round2_candidates_20261110}"
AVG="/public/home/a094f4d7/voice_projects/code/n019_official/scripts/average_vocoder_checkpoints.py"

mkdir -p "$OUT"

avg() {
  local name="$1"
  shift
  "$PY" "$AVG" --effective-weight-norm "$@" \
    --out "$OUT/generator_avg_soup2_${name}.pt"
}

avg quad_w40_30_20_10 \
  --checkpoint "$SRC/d5_84.pt" --weight 0.40 \
  --checkpoint "$SRC/d5_88.pt" --weight 0.30 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.20 \
  --checkpoint "$SRC/d5_96.pt" --weight 0.10

avg quad_w35_30_20_15 \
  --checkpoint "$SRC/d5_84.pt" --weight 0.35 \
  --checkpoint "$SRC/d5_88.pt" --weight 0.30 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.20 \
  --checkpoint "$SRC/d5_96.pt" --weight 0.15

avg quad_w30_30_25_15 \
  --checkpoint "$SRC/d5_84.pt" --weight 0.30 \
  --checkpoint "$SRC/d5_88.pt" --weight 0.30 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.25 \
  --checkpoint "$SRC/d5_96.pt" --weight 0.15

avg quad_w30_35_20_15 \
  --checkpoint "$SRC/d5_84.pt" --weight 0.30 \
  --checkpoint "$SRC/d5_88.pt" --weight 0.35 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.20 \
  --checkpoint "$SRC/d5_96.pt" --weight 0.15

avg quint_84_88_90_92_96 \
  --checkpoint "$SRC/d5_84.pt" \
  --checkpoint "$SRC/d5_88.pt" \
  --checkpoint "$SRC/d5_90.pt" \
  --checkpoint "$SRC/d5_92.pt" \
  --checkpoint "$SRC/d5_96.pt"

avg quint_84_88_92_94_96 \
  --checkpoint "$SRC/d5_84.pt" \
  --checkpoint "$SRC/d5_88.pt" \
  --checkpoint "$SRC/d5_92.pt" \
  --checkpoint "$SRC/d5_94.pt" \
  --checkpoint "$SRC/d5_96.pt"

avg hex_84_88_90_92_94_96 \
  --checkpoint "$SRC/d5_84.pt" \
  --checkpoint "$SRC/d5_88.pt" \
  --checkpoint "$SRC/d5_90.pt" \
  --checkpoint "$SRC/d5_92.pt" \
  --checkpoint "$SRC/d5_94.pt" \
  --checkpoint "$SRC/d5_96.pt"

avg quad_plus90_10 \
  --checkpoint "$SRC/d5_84.pt" --weight 0.225 \
  --checkpoint "$SRC/d5_88.pt" --weight 0.225 \
  --checkpoint "$SRC/d5_90.pt" --weight 0.10 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.225 \
  --checkpoint "$SRC/d5_96.pt" --weight 0.225

avg quad_plus94_10 \
  --checkpoint "$SRC/d5_84.pt" --weight 0.225 \
  --checkpoint "$SRC/d5_88.pt" --weight 0.225 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.225 \
  --checkpoint "$SRC/d5_94.pt" --weight 0.10 \
  --checkpoint "$SRC/d5_96.pt" --weight 0.225

"$PY" "$AVG" --effective-weight-norm \
  --allow-nonarchitectural-config-diff \
  --checkpoint "$SRC/d5_84.pt" --weight 0.225 \
  --checkpoint "$SRC/d5_88.pt" --weight 0.225 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.225 \
  --checkpoint "$SRC/d5_96.pt" --weight 0.225 \
  --checkpoint "$SRC/d6_88.pt" --weight 0.05 \
  --checkpoint "$SRC/d6_92.pt" --weight 0.05 \
  --out "$OUT/generator_avg_soup2_quad_plus_d6_10.pt"

"$PY" "$AVG" --effective-weight-norm \
  --allow-nonarchitectural-config-diff \
  --checkpoint "$SRC/d5_84.pt" --weight 0.20 \
  --checkpoint "$SRC/d5_88.pt" --weight 0.20 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.20 \
  --checkpoint "$SRC/d5_96.pt" --weight 0.20 \
  --checkpoint "$SRC/d6_88.pt" --weight 0.10 \
  --checkpoint "$SRC/d6_92.pt" --weight 0.10 \
  --out "$OUT/generator_avg_soup2_quad_plus_d6_20.pt"

"$PY" "$AVG" --effective-weight-norm \
  --allow-nonarchitectural-config-diff \
  --checkpoint "$SRC/d5_84.pt" --weight 0.125 \
  --checkpoint "$SRC/d5_88.pt" --weight 0.25 \
  --checkpoint "$SRC/d5_92.pt" --weight 0.25 \
  --checkpoint "$SRC/d5_96.pt" --weight 0.125 \
  --checkpoint "$SRC/d6_88.pt" --weight 0.125 \
  --checkpoint "$SRC/d6_92.pt" --weight 0.125 \
  --out "$OUT/generator_avg_soup2_quad_cross_equal.pt"

sha256sum "$OUT"/*.pt
