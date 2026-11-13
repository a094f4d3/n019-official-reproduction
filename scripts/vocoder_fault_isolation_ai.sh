#!/usr/bin/env bash

set -u

ROOT="${N019_OFFICIAL_ROOT:?Set N019_OFFICIAL_ROOT}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

OUT="${N019_FAULT_OUT:?Set N019_FAULT_OUT}"
RECORDS="${N019_FAULT_RECORDS:?Set N019_FAULT_RECORDS}"
EMBEDDINGS="${N019_FAULT_EMBEDDINGS:?Set N019_FAULT_EMBEDDINGS}"
mkdir -p "$OUT" "$OUT/data"

export PYTHONFAULTHANDLER=1
export TORCH_SHOW_CPP_STACKTRACES=1
export HIP_LAUNCH_BLOCKING=1
export CUDA_LAUNCH_BLOCKING=1

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

head -n 16 "$RECORDS" > "$OUT/data/unit_records_smoke16.jsonl"
echo "SMOKE_SUBSET rows=$(wc -l < "$OUT/data/unit_records_smoke16.jsonl")"

run_case() {
  local name="$1"
  shift
  echo "CASE_START $name $(date -Is)"
  set +e
  timeout --signal=KILL 300 "$@" > "$OUT/${name}.log" 2>&1
  local code=$?
  set -e
  echo "CASE_END $name exit=$code $(date -Is)"
  tail -n 25 "$OUT/${name}.log" || true
  return "$code"
}

set -e
run_case model_smoke_b2 \
  python -u -m n019.vocoder_smoke \
    --out "$OUT/model_smoke_b2" \
    --batch-size 2 \
    --frames 64 || true

run_case direct_b2_w0 \
  python -u -m n019.vocoder \
    --records "$OUT/data/unit_records_smoke16.jsonl" \
    --embeddings "$EMBEDDINGS" \
    --speaker-dim 250 \
    --embedding-level speaker \
    --out "$OUT/direct_b2_w0" \
    --steps 2 \
    --lr 2e-4 \
    --grad-clip-norm 0.0 \
    --max-hours 0.05 \
    --batch-size 2 \
    --workers 0 \
    --checkpoint-interval 1 \
    --generator-snapshot-interval 0 \
    --keep-interval 1000 \
    --validation-interval 1 \
    --validation-limit 2 \
    --selection-policy mos_offline \
    --early-stop-patience 0 \
    --device cuda \
    --bf16 || true

run_case direct_b16_w0 \
  python -u -m n019.vocoder \
    --records "$OUT/data/unit_records_smoke16.jsonl" \
    --embeddings "$EMBEDDINGS" \
    --speaker-dim 250 \
    --embedding-level speaker \
    --out "$OUT/direct_b16_w0" \
    --steps 1 \
    --lr 2e-4 \
    --grad-clip-norm 0.0 \
    --max-hours 0.05 \
    --batch-size 16 \
    --workers 0 \
    --checkpoint-interval 1 \
    --generator-snapshot-interval 0 \
    --keep-interval 1000 \
    --validation-interval 1 \
    --validation-limit 2 \
    --selection-policy mos_offline \
    --early-stop-patience 0 \
    --device cuda \
    --bf16 || true

run_case torchrun_b2_w0 \
  python -m torch.distributed.run --standalone --nnodes=1 --nproc_per_node=1 \
    -m n019.vocoder \
    --records "$OUT/data/unit_records_smoke16.jsonl" \
    --embeddings "$EMBEDDINGS" \
    --speaker-dim 250 \
    --embedding-level speaker \
    --out "$OUT/torchrun_b2_w0" \
    --steps 1 \
    --lr 2e-4 \
    --grad-clip-norm 0.0 \
    --max-hours 0.05 \
    --batch-size 2 \
    --workers 0 \
    --checkpoint-interval 1 \
    --generator-snapshot-interval 0 \
    --keep-interval 1000 \
    --validation-interval 1 \
    --validation-limit 2 \
    --selection-policy mos_offline \
    --early-stop-patience 0 \
    --device cuda \
    --bf16 || true

echo "VOCoder_FAULT_ISOLATION_COMPLETE out=$OUT"
