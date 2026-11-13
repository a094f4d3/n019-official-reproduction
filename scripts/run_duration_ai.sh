#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export N019_VOICE_ROOT="$(cd "$ROOT/../.." && pwd)"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

KIND="${N019_DURATION_EMBEDDING_KIND:-nt}"
EPOCHS="${N019_DURATION_EPOCHS:-30}"
BATCH_SIZE="${N019_DURATION_BATCH_SIZE:-32}"
WORKERS="${N019_DURATION_WORKERS:-4}"
RECORDS="$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_100/unit_records.jsonl"

case "$KIND" in
  nt)
    SPEAKER_DIM=250
    EMBEDDINGS="${N019_DURATION_EMBEDDINGS:-$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_100_nt/nt_speaker_embeddings.npz}"
    DEFAULT_RUN_NAME="duration_nt_main"
    ;;
  ecapa)
    SPEAKER_DIM=192
    EMBEDDINGS="${N019_DURATION_EMBEDDINGS:-$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_100_ecapa/ecapa_speaker_embeddings.npz}"
    DEFAULT_RUN_NAME="duration_ecapa_main"
    ;;
  pred)
    SPEAKER_DIM=0
    EMBEDDINGS=""
    DEFAULT_RUN_NAME="duration_pred_main"
    ;;
  *)
    echo "N019_DURATION_EMBEDDING_KIND must be nt, ecapa, or pred" >&2
    exit 1
    ;;
esac

if [[ "$KIND" == "pred" ]]; then
  TRAINING_EMBEDDING_KIND=none
else
  TRAINING_EMBEDDING_KIND="$KIND"
fi

OUT="${N019_DURATION_OUT:-$N019_OFFICIAL_RUNS/${N019_DURATION_RUN_NAME:-$DEFAULT_RUN_NAME}}"
for required in "$RECORDS"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing duration training input: $required" >&2
    exit 1
  fi
done
if [[ "$SPEAKER_DIM" -gt 0 && ! -f "$EMBEDDINGS" ]]; then
  echo "Missing duration speaker embeddings: $EMBEDDINGS" >&2
  exit 1
fi

mkdir -p "$OUT"
RESUME_FLAG=()
if [[ -f "$OUT/last.pt" ]]; then
  RESUME_FLAG=(--resume)
fi

{
  echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
  echo "job=${SLURM_JOB_ID:-manual} scope=duration_training"
  echo "kind=$KIND"
  echo "speaker_dim=$SPEAKER_DIM"
  echo "records=$RECORDS"
  echo "embeddings=${EMBEDDINGS:-none}"
  echo "epochs=$EPOCHS"
  echo "batch_size=$BATCH_SIZE"
  echo "out=$OUT"
  echo "resume=${#RESUME_FLAG[@]}"
} | tee "$OUT/launch.txt"

export N019_PREFLIGHT_MANIFEST="$RECORDS"
bash "$ROOT/scripts/preflight_dcu_remote.sh"

EMBEDDING_ARGS=()
if [[ "$SPEAKER_DIM" -gt 0 ]]; then
  EMBEDDING_ARGS=(--embeddings "$EMBEDDINGS")
fi

python -u -m n019.duration \
  --records "$RECORDS" \
  "${EMBEDDING_ARGS[@]}" \
  --speaker-dim "$SPEAKER_DIM" \
  --embedding-kind "$TRAINING_EMBEDDING_KIND" \
  --epochs "$EPOCHS" \
  --batch-size "$BATCH_SIZE" \
  --workers "$WORKERS" \
  --device cuda \
  --out "$OUT" \
  "${RESUME_FLAG[@]}"

echo "DURATION_TRAINING_COMPLETE kind=$KIND out=$OUT"
