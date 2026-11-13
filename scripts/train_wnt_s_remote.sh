#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SUFFIX="${N019_DATA_SUFFIX:-_n019}"
RUN_NAME="${N019_WNT_S_RUN_NAME:-wnt_s}"
DATA="$N019_OFFICIAL_DATA/vpc/data/train-clean-360$SUFFIX"
BASE_MODEL="${N019_WNT_BASE_MODEL:-$N019_OFFICIAL_MODELS/wpro}"
OUT="${N019_WNT_S_OUT:-$N019_OFFICIAL_RUNS/$RUN_NAME}"
EPOCHS="${N019_WNT_S_EPOCHS:-20}"
NPROC="${N019_NPROC:-4}"
TOTAL_BATCH="${N019_WNT_S_TOTAL_BATCH:-16}"
WORKERS="${N019_WNT_S_WORKERS:-4}"
LR="${N019_WNT_S_LR:-1e-3}"
HEAD_LR="${N019_WNT_S_HEAD_LR:-1e-3}"
FREEZE_WAVLM="${N019_WNT_S_FREEZE_WAVLM:-1}"
if (( NPROC < 1 )); then
  echo "N019_NPROC must be positive" >&2
  exit 1
fi
if (( TOTAL_BATCH % NPROC != 0 )); then
  echo "Total W-NT batch $TOTAL_BATCH must divide across $NPROC DCUs" >&2
  exit 1
fi
BATCH_PER_RANK=$((TOTAL_BATCH / NPROC))
if (( BATCH_PER_RANK < 1 )); then
  echo "Per-rank W-NT batch must be positive" >&2
  exit 1
fi
MAX_HOURS="${N019_WNT_S_MAX_HOURS:-$((48 / NPROC))}"
AAM_MARGIN="${N019_WNT_S_AAM_MARGIN:-0.2}"
AAM_SCALE="${N019_WNT_S_AAM_SCALE:-30}"

for required in \
  "$DATA/wav.scp" \
  "$DATA/utt2spk" \
  "$BASE_MODEL/config.json" \
  "$BASE_MODEL/model.safetensors" \
  "$BASE_MODEL/spk_embeddings.py"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing W-NT S input: $required" >&2
    exit 1
  fi
done

mkdir -p "$OUT"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "date=$(date -Is)"
  echo "suffix=$SUFFIX"
  echo "train_data=$DATA"
  echo "base_model=$BASE_MODEL"
  echo "out=$OUT"
  echo "epochs=$EPOCHS"
  echo "nproc=$NPROC total_batch=$TOTAL_BATCH batch_per_rank=$BATCH_PER_RANK"
  echo "lr=$LR head_lr=$HEAD_LR freeze_wavlm=$FREEZE_WAVLM"
  echo "max_hours=$MAX_HOURS"
} | tee "$OUT/launch.txt"

EXTRA_ARGS=()
if [[ "$FREEZE_WAVLM" == "1" ]]; then
  EXTRA_ARGS+=(--freeze-wavlm)
fi

python -m torch.distributed.run \
  --standalone \
  --nnodes=1 \
  --nproc_per_node="$NPROC" \
  -m n019.wnt_attack \
  --train-data-dir "$DATA" \
  --base-model "$BASE_MODEL" \
  --out "$OUT" \
  --expected-utterances 104014 \
  --expected-speakers 921 \
  --segment-seconds 3.0 \
  --batch-size "$BATCH_PER_RANK" \
  --epochs "$EPOCHS" \
  --lr "$LR" \
  --head-lr "$HEAD_LR" \
  --weight-decay 0.000002 \
  --aam-margin "$AAM_MARGIN" \
  --aam-scale "$AAM_SCALE" \
  --workers "$WORKERS" \
  --max-hours "$MAX_HOURS" \
  --checkpoint-interval 500 \
  --device cuda \
  --bf16 \
  "${EXTRA_ARGS[@]}"
