#!/usr/bin/env bash

set -u

ROOT="${N019_OFFICIAL_ROOT:?Set N019_OFFICIAL_ROOT}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

OUT="${N019_FIXED_OUT:?Set N019_FIXED_OUT}"
RECORDS="${N019_FIXED_RECORDS:?Set N019_FIXED_RECORDS}"
EMBEDDINGS="${N019_FIXED_EMBEDDINGS:?Set N019_FIXED_EMBEDDINGS}"
mkdir -p "$OUT/data"

export PYTHONFAULTHANDLER=1
export TORCH_SHOW_CPP_STACKTRACES=1
export N019_CUDNN_BENCHMARK=0
export N019_PIN_MEMORY=0

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"
head -n 16 "$RECORDS" > "$OUT/data/unit_records_smoke16.jsonl"
echo "FIXED_SMOKE_SUBSET rows=$(wc -l < "$OUT/data/unit_records_smoke16.jsonl")"

run_case() {
  local name="$1"
  local seconds="$2"
  shift 2
  echo "CASE_START $name $(date -Is)"
  set +e
  timeout --signal=KILL "$seconds" "$@" > "$OUT/${name}.log" 2>&1
  local code=$?
  set -e
  echo "CASE_END $name exit=$code $(date -Is)"
  tail -n 30 "$OUT/${name}.log" || true
  return "$code"
}

run_common=(
  --records "$OUT/data/unit_records_smoke16.jsonl"
  --embeddings "$EMBEDDINGS"
  --speaker-dim 250
  --embedding-level speaker
  --lr 2e-4
  --grad-clip-norm 0.0
  --max-hours 0.05
  --checkpoint-interval 1
  --generator-snapshot-interval 0
  --keep-interval 1000
  --validation-interval 1
  --validation-limit 2
  --selection-policy mos_offline
  --early-stop-patience 0
  --device cuda
  --bf16
)

set -e
run_case direct_b2_w0 180 python -u -m n019.vocoder \
  "${run_common[@]}" \
  --out "$OUT/direct_b2_w0" \
  --steps 2 \
  --batch-size 2 \
  --workers 0 || true

run_case direct_b16_w0 180 python -u -m n019.vocoder \
  "${run_common[@]}" \
  --out "$OUT/direct_b16_w0" \
  --steps 1 \
  --batch-size 16 \
  --workers 0 || true

run_case direct_b16_w4 240 python -u -m n019.vocoder \
  "${run_common[@]}" \
  --out "$OUT/direct_b16_w4" \
  --steps 2 \
  --batch-size 16 \
  --workers 4 || true

echo "N019_FIXED_VOCODER_SMOKE_COMPLETE out=$OUT"
