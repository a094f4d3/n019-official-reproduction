#!/usr/bin/env bash

set -u

ROOT="${N019_OFFICIAL_ROOT:?Set N019_OFFICIAL_ROOT}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

OUT="${N019_PROBE_OUT:?Set N019_PROBE_OUT}"
RECORDS="${N019_PROBE_RECORDS:?Set N019_PROBE_RECORDS}"
EMBEDDINGS="${N019_PROBE_EMBEDDINGS:?Set N019_PROBE_EMBEDDINGS}"
mkdir -p "$OUT/data"

export PYTHONFAULTHANDLER=1
export TORCH_SHOW_CPP_STACKTRACES=1
export N019_CUDNN_BENCHMARK=0
export N019_PIN_MEMORY=0
export N019_STAGE_TRACE=1
export N019_STACK_DUMP_SECONDS=30

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"
head -n 8 "$RECORDS" > "$OUT/data/unit_records_probe8.jsonl"
echo "STAGE_PROBE_SUBSET rows=$(wc -l < "$OUT/data/unit_records_probe8.jsonl")"

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
  tail -n 60 "$OUT/${name}.log" || true
  return "$code"
}

common=(
  --records "$OUT/data/unit_records_probe8.jsonl"
  --embeddings "$EMBEDDINGS"
  --speaker-dim 250
  --embedding-level speaker
  --lr 2e-4
  --grad-clip-norm 0.0
  --max-hours 0.02
  --checkpoint-interval 1
  --generator-snapshot-interval 0
  --keep-interval 1000
  --validation-interval 1
  --validation-limit 1
  --selection-policy mos_offline
  --early-stop-patience 0
  --device cuda
  --steps 1
  --batch-size 2
  --workers 0
)

set -e
run_case fp32_b2 120 python -u -m n019.vocoder \
  "${common[@]}" \
  --out "$OUT/fp32_b2" || true

run_case bf16_b2 120 python -u -m n019.vocoder \
  "${common[@]}" \
  --bf16 \
  --out "$OUT/bf16_b2" || true

echo "N019_STAGE_PROBE_COMPLETE out=$OUT"
