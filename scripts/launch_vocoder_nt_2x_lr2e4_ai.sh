#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export N019_OFFICIAL_ROOT="$ROOT"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

OUT="${N019_LR2E4_OUT:-$N019_OFFICIAL_RUNS/vocoder_nt_2x_lr2e4_fresh}"
STEPS="${N019_LR2E4_STEPS:-400000}"
MAX_HOURS="${N019_LR2E4_MAX_HOURS:-2.0}"
NPROC="${N019_LR2E4_NPROC:-1}"
TOTAL_BATCH="${N019_LR2E4_TOTAL_BATCH:-16}"

test ! -e "$OUT/last.pt" || {
  echo "Refusing to overwrite existing run: $OUT" >&2
  exit 1
}
if [[ -d "$OUT" ]] && find "$OUT" -mindepth 1 -print0 | grep -zq .; then
  echo "Refusing to use non-empty output directory: $OUT" >&2
  exit 1
fi

python - <<'PY'
from n019.vocoder import UnitVocoderConfig
from n019.training_recipe import training_recipe_metadata

config = UnitVocoderConfig()
if config.learning_rate != 2e-4:
    raise SystemExit(f"Unexpected learning rate: {config.learning_rate}")
if config.grad_clip_norm != 0.0:
    raise SystemExit(f"Unexpected gradient clipping: {config.grad_clip_norm}")
recipe = training_recipe_metadata()
if recipe["feature_matching_probe"] != 4.0:
    raise SystemExit(f"Unexpected feature-matching probe: {recipe}")
print("N019_LR2E4_RECIPE_OK", recipe["version"], config.learning_rate)
PY

export N019_NPROC="$NPROC"
export N019_VOCODER_TOTAL_BATCH="$TOTAL_BATCH"
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RUN_NAME=vocoder_nt_2x_lr2e4_fresh
export N019_VOCODER_OUT="$OUT"
export N019_VOCODER_STEPS="$STEPS"
export N019_VOCODER_MAX_HOURS="$MAX_HOURS"
export N019_VOCODER_CHECKPOINT_INTERVAL="${N019_LR2E4_CHECKPOINT_INTERVAL:-2000}"
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL="${N019_LR2E4_SNAPSHOT_INTERVAL:-5000}"
export N019_VOCODER_KEEP_INTERVAL="${N019_LR2E4_KEEP_INTERVAL:-50000}"
export N019_VOCODER_VALIDATION_INTERVAL="${N019_LR2E4_VALIDATION_INTERVAL:-2000}"
export N019_VOCODER_SELECTION_POLICY=mos_offline
export N019_VOCODER_EARLY_STOP_PATIENCE=0
export N019_VOCODER_LR=2e-4
export N019_VOCODER_GRAD_CLIP_NORM=0.0
export N019_CUDNN_BENCHMARK="${N019_CUDNN_BENCHMARK:-0}"
export N019_PIN_MEMORY="${N019_PIN_MEMORY:-0}"

bash "$ROOT/scripts/run_vocoder_ddp.sh"
echo "N019_LR2E4_TRAINING_COMPLETE out=$OUT"
