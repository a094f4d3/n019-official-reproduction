#!/bin/bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SOURCE="$HOME/voice_projects/data/n019_official/processed/units/layer9_eval_20261116/dev100/unit_records.jsonl"
TARGET_EMBEDDINGS="/public/home/a094f4d6/voice_projects/tmp/n019_privacy_fix_20261111/target_speaker_mean32_all1158_shrink01.npz"
ROOT_DIR="$N019_OFFICIAL_RUNS/vocoder_selection_layer9_matcheddur_20261117/candidates"
OUT="$N019_OFFICIAL_RUNS/layer9_dev_target_shift_20261117"

test "$(wc -l < "$SOURCE")" = 100
test -s "$TARGET_EMBEDDINGS"
mkdir -p "$OUT"

export OMP_NUM_THREADS=8
export MKL_NUM_THREADS=8

python -u -m n019.speaker_diagnostics \
  --source "$SOURCE" \
  --anon "$ROOT_DIR/baseline/anonymised/anon.jsonl" \
  --target-embeddings "$TARGET_EMBEDDINGS" \
  --out "$OUT/baseline.json" \
  --device cpu

python -u -m n019.speaker_diagnostics \
  --source "$SOURCE" \
  --anon "$ROOT_DIR/generator_step00008000/anonymised/anon.jsonl" \
  --target-embeddings "$TARGET_EMBEDDINGS" \
  --out "$OUT/layer9_8k.json" \
  --device cpu

sha256sum \
  "$OUT/baseline.json" \
  "$OUT/layer9_8k.json"
echo "N019_LAYER9_TARGET_SHIFT_COMPLETE out=$OUT"
