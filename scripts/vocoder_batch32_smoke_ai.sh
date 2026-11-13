#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:?Set N019_OFFICIAL_ROOT}"
OUT="${N019_BATCH32_SMOKE_OUT:?Set N019_BATCH32_SMOKE_OUT}"
RECORDS="${N019_BATCH32_SMOKE_RECORDS:?Set N019_BATCH32_SMOKE_RECORDS}"
EMBEDDINGS="${N019_BATCH32_SMOKE_EMBEDDINGS:?Set N019_BATCH32_SMOKE_EMBEDDINGS}"

source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

mkdir -p "$OUT/data"
head -n 96 "$RECORDS" > "$OUT/data/unit_records_probe96.jsonl"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

export N019_NPROC=1
export N019_VOCODER_TOTAL_BATCH=32
export N019_VOCODER_WORKERS=0
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RUN_NAME=batch32_smoke
export N019_VOCODER_OUT="$OUT/run"
export N019_VOCODER_RECORDS="$OUT/data/unit_records_probe96.jsonl"
export N019_VOCODER_EMBEDDINGS="$EMBEDDINGS"
export N019_VOCODER_STEPS=3
export N019_VOCODER_MAX_HOURS=0.02
export N019_VOCODER_CHECKPOINT_INTERVAL=1
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL=0
export N019_VOCODER_KEEP_INTERVAL=1000
export N019_VOCODER_VALIDATION_INTERVAL=2000
export N019_VOCODER_SELECTION_POLICY=mos_offline
export N019_VOCODER_EARLY_STOP_PATIENCE=0
export N019_VOCODER_LR=2e-4
export N019_VOCODER_GRAD_CLIP_NORM=0.0
export N019_VOCODER_BF16=1
export N019_STAGE_TRACE=1

echo "batch32_smoke_start host=$(hostname) date=$(date -Is)"
bash "$ROOT/scripts/run_vocoder_ddp.sh"
echo "batch32_smoke_complete date=$(date -Is)"
