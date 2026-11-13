#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export N019_OFFICIAL_ROOT="$ROOT"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

OUT="${N019_LR2E4_OUT:?Set N019_LR2E4_OUT to the existing fresh run directory}"
STEPS="${N019_LR2E4_STEPS:-400000}"
MAX_HOURS="${N019_LR2E4_MAX_HOURS:-1.75}"
NPROC="${N019_LR2E4_NPROC:-1}"
TOTAL_BATCH="${N019_LR2E4_TOTAL_BATCH:-16}"

test -f "$OUT/last.pt" || {
  echo "Continuation requires an existing last.pt: $OUT/last.pt" >&2
  exit 1
}

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

import torch

from n019.training_recipe import training_recipe_metadata

out = Path(sys.argv[1])
checkpoint = torch.load(out / "last.pt", map_location="cpu", weights_only=False)
config = checkpoint.get("config") or {}
if abs(float(config.get("learning_rate", -1.0)) - 2e-4) > 1e-12:
    raise SystemExit(f"Unexpected resumed learning rate: {config.get('learning_rate')}")
if abs(float(config.get("grad_clip_norm", -1.0))) > 1e-12:
    raise SystemExit(f"Unexpected resumed gradient clipping: {config.get('grad_clip_norm')}")
if checkpoint.get("recipe") != training_recipe_metadata():
    raise SystemExit("Resumed checkpoint recipe does not match the deployed recipe")
print(
    json.dumps(
        {
            "out": str(out),
            "step": checkpoint.get("step"),
            "lr": config.get("learning_rate"),
            "grad_clip_norm": config.get("grad_clip_norm"),
            "recipe": checkpoint.get("recipe"),
        },
        indent=2,
        sort_keys=True,
    )
)
PY

export N019_NPROC="$NPROC"
export N019_VOCODER_TOTAL_BATCH="$TOTAL_BATCH"
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RUN_NAME="$(basename "$OUT")"
export N019_VOCODER_OUT="$OUT"
export N019_VOCODER_STEPS="$STEPS"
export N019_VOCODER_MAX_HOURS="$MAX_HOURS"
export N019_VOCODER_CHECKPOINT_INTERVAL="${N019_LR2E4_CHECKPOINT_INTERVAL:-1000}"
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL="${N019_LR2E4_SNAPSHOT_INTERVAL:-2000}"
export N019_VOCODER_KEEP_INTERVAL="${N019_LR2E4_KEEP_INTERVAL:-50000}"
export N019_VOCODER_VALIDATION_INTERVAL="${N019_LR2E4_VALIDATION_INTERVAL:-2000}"
export N019_VOCODER_SELECTION_POLICY=mos_offline
export N019_VOCODER_EARLY_STOP_PATIENCE=0
export N019_VOCODER_LR=2e-4
export N019_VOCODER_GRAD_CLIP_NORM=0.0
export N019_CUDNN_BENCHMARK="${N019_CUDNN_BENCHMARK:-0}"
export N019_PIN_MEMORY="${N019_PIN_MEMORY:-0}"
export N019_SKIP_PATH_VERIFY="${N019_LR2E4_SKIP_PATH_VERIFY:-1}"
export N019_TRAINING_DATA_MARKER="${N019_LR2E4_DATA_MARKER:-$N019_OFFICIAL_LOGS/d6_training_data_ready.json}"
export N019_TRAINING_EXPECTED_ROWS="${N019_LR2E4_EXPECTED_ROWS:-33236}"

STAMP="$(date +%Y%m%d_%H%M%S)"
bash "$ROOT/scripts/run_vocoder_ddp.sh"
python "$ROOT/scripts/extract_last_generator_remote.py" \
  --source "$OUT/last.pt" \
  --out "$OUT/generator_segment_${STAMP}.pt"
sha256sum "$OUT/last.pt" "$OUT/generator_segment_${STAMP}.pt" \
  | tee "$OUT/segment_${STAMP}_sha256.txt"
echo "N019_LR2E4_CONTINUE_COMPLETE out=$OUT segment=$STAMP"
