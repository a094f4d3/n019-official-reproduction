#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [[ ! -f "$ROOT/hpc/activate_n019_official.sh" ]]; then
    ROOT=""
    for candidate in \
      /mnt/data/voice_projects/code/n019_official \
      "/public/home/$(id -un)/voice_projects/code/n019_official" \
      "$HOME/voice_projects/code/n019_official"; do
      if [[ -d "$candidate" ]]; then
        ROOT="$candidate"
        break
      fi
    done
  fi
fi
if [[ -z "$ROOT" ]]; then
  echo "Cannot locate n019_official project root" >&2
  exit 1
fi
export N019_VOICE_ROOT="$(cd "$ROOT/../.." && pwd)"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

NPROC="${N019_NPROC:-4}"
STEPS="${N019_VOCODER_STEPS:-400000}"
DEFAULT_MAX_HOURS=$((48 / NPROC))
MAX_HOURS="${N019_VOCODER_MAX_HOURS:-$DEFAULT_MAX_HOURS}"
CHECKPOINT_INTERVAL="${N019_VOCODER_CHECKPOINT_INTERVAL:-2000}"
GENERATOR_SNAPSHOT_INTERVAL="${N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL:-10000}"
KEEP_INTERVAL="${N019_VOCODER_KEEP_INTERVAL:-50000}"
VALIDATION_INTERVAL="${N019_VOCODER_VALIDATION_INTERVAL:-2000}"
SELECTION_POLICY="${N019_VOCODER_SELECTION_POLICY:-mos_offline}"
EARLY_STOP_MIN_STEPS="${N019_VOCODER_EARLY_STOP_MIN_STEPS:-20000}"
EARLY_STOP_PATIENCE="${N019_VOCODER_EARLY_STOP_PATIENCE:-15}"
EARLY_STOP_MIN_DELTA="${N019_VOCODER_EARLY_STOP_MIN_DELTA:-0.001}"
WORKERS="${N019_VOCODER_WORKERS:-4}"
TOTAL_BATCH="${N019_VOCODER_TOTAL_BATCH:-32}"
LR="${N019_VOCODER_LR:-2e-4}"
OPTIMIZER="${N019_VOCODER_OPTIMIZER:-adamw}"
GRAD_CLIP_NORM="${N019_VOCODER_GRAD_CLIP_NORM:-0.0}"
BF16="${N019_VOCODER_BF16:-1}"
VOCODER_TYPE="${N019_VOCODER_TYPE:-nt}"
EMBEDDING_LEVEL="${N019_VOCODER_EMBEDDING_LEVEL:-speaker}"
SPEAKER_EMBEDDING_SCALE="${N019_VOCODER_SPEAKER_EMBEDDING_SCALE:-1.0}"
SPEAKER_SWAP_PROBABILITY="${N019_VOCODER_SPEAKER_SWAP_PROBABILITY:-0.0}"
SPEAKER_SWAP_EMBEDDINGS="${N019_VOCODER_SPEAKER_SWAP_EMBEDDINGS:-}"
case "$VOCODER_TYPE" in
  nt)
    DEFAULT_SPEAKER_DIM=250
    DEFAULT_EMBEDDINGS="$N019_OFFICIAL_DATA/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz"
    DEFAULT_RUN_NAME="vocoder_nt_ddp"
    ;;
  ecapa)
    DEFAULT_SPEAKER_DIM=192
    DEFAULT_EMBEDDINGS="$N019_OFFICIAL_DATA/processed/embeddings/libritts_train_clean_100_ecapa/ecapa_speaker_embeddings.npz"
    DEFAULT_RUN_NAME="vocoder_ecapa_ddp"
    ;;
  *)
    echo "N019_VOCODER_TYPE must be nt or ecapa" >&2
    exit 1
    ;;
esac
SPEAKER_DIM="${N019_VOCODER_SPEAKER_DIM:-$DEFAULT_SPEAKER_DIM}"
EMBEDDINGS="${N019_VOCODER_EMBEDDINGS:-$DEFAULT_EMBEDDINGS}"
RUN_NAME="${N019_VOCODER_RUN_NAME:-$DEFAULT_RUN_NAME}"
OUT="${N019_VOCODER_OUT:-$N019_OFFICIAL_RUNS/$RUN_NAME}"
RECORDS="${N019_VOCODER_RECORDS:-$N019_OFFICIAL_DATA/processed/units/libritts_train_clean_100/unit_records.jsonl}"
VALIDATION_RECORDS="${N019_VOCODER_VALIDATION_RECORDS:-}"
VALIDATION_EMBEDDINGS="${N019_VOCODER_VALIDATION_EMBEDDINGS:-}"
RESUME_SHA256="${N019_VOCODER_RESUME_SHA256:-}"

if (( NPROC < 1 )); then
  echo "N019_NPROC must be positive" >&2
  exit 1
fi
if (( TOTAL_BATCH % NPROC != 0 )); then
  echo "Total batch $TOTAL_BATCH must divide across $NPROC DCUs" >&2
  exit 1
fi
BATCH_PER_RANK=$((TOTAL_BATCH / NPROC))
if (( BATCH_PER_RANK < 1 )); then
  echo "Batch per rank must be positive" >&2
  exit 1
fi
if (( EARLY_STOP_MIN_STEPS < 0 || EARLY_STOP_PATIENCE < 0 )); then
  echo "Early-stop step and patience values must be non-negative" >&2
  exit 1
fi
if (( GENERATOR_SNAPSHOT_INTERVAL < 0 )); then
  echo "N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL must be non-negative" >&2
  exit 1
fi
if [[ "$SELECTION_POLICY" != "mel_l1" && "$SELECTION_POLICY" != "mos_offline" ]]; then
  echo "N019_VOCODER_SELECTION_POLICY must be mel_l1 or mos_offline" >&2
  exit 1
fi
if [[ "$BF16" != "0" && "$BF16" != "1" ]]; then
  echo "N019_VOCODER_BF16 must be 0 or 1" >&2
  exit 1
fi
if [[ "$EMBEDDING_LEVEL" != "speaker" && "$EMBEDDING_LEVEL" != "utterance" ]]; then
  echo "N019_VOCODER_EMBEDDING_LEVEL must be speaker or utterance" >&2
  exit 1
fi
if ! awk -v value="$SPEAKER_EMBEDDING_SCALE" 'BEGIN { exit !(value > 0) }'; then
  echo "N019_VOCODER_SPEAKER_EMBEDDING_SCALE must be positive" >&2
  exit 1
fi
if ! awk -v value="$SPEAKER_SWAP_PROBABILITY" \
  'BEGIN { exit !(value >= 0 && value <= 1) }'; then
  echo "N019_VOCODER_SPEAKER_SWAP_PROBABILITY must be in [0, 1]" >&2
  exit 1
fi
SPEAKER_SWAP_ARGS=()
if [[ -n "$SPEAKER_SWAP_EMBEDDINGS" ]]; then
  if [[ ! -f "$SPEAKER_SWAP_EMBEDDINGS" ]]; then
    echo "Missing speaker swap embeddings: $SPEAKER_SWAP_EMBEDDINGS" >&2
    exit 1
  fi
  SPEAKER_SWAP_ARGS=(
    --speaker-swap-embeddings "$SPEAKER_SWAP_EMBEDDINGS"
  )
fi
if [[ "$OPTIMIZER" != "adam" && "$OPTIMIZER" != "adamw" ]]; then
  echo "N019_VOCODER_OPTIMIZER must be adam or adamw" >&2
  exit 1
fi
if ! awk -v value="$EARLY_STOP_MIN_DELTA" 'BEGIN { exit !(value >= 0) }'; then
  echo "N019_VOCODER_EARLY_STOP_MIN_DELTA must be non-negative" >&2
  exit 1
fi
if [[ ! -f "$RECORDS" ]]; then
  echo "Missing vocoder records: $RECORDS" >&2
  exit 1
fi
if [[ ! -f "$EMBEDDINGS" ]]; then
  echo "Missing vocoder embeddings: $EMBEDDINGS" >&2
  exit 1
fi
if [[ "${N019_SKIP_PATH_VERIFY:-0}" == "1" ]]; then
  marker="${N019_TRAINING_DATA_MARKER:?Set N019_TRAINING_DATA_MARKER when N019_SKIP_PATH_VERIFY=1}"
  python "$ROOT/scripts/verify_training_data_marker.py" \
    --records "$RECORDS" \
    --embeddings "$EMBEDDINGS" \
    --marker "$marker" \
    --expected-rows "${N019_TRAINING_EXPECTED_ROWS:?Set N019_TRAINING_EXPECTED_ROWS}"
else
  python "$ROOT/scripts/verify_local_unit_records.py" \
    --records "$RECORDS" \
    --root "$N019_VOICE_ROOT" \
    --allow-root "${N019_SHARED_VOICE_ROOT:-/public/home/a094f4d4/voice_projects}" \
    --fields audio,codes_path,kmeans_codebook
fi
python "$ROOT/scripts/verify_n019_training_recipe.py"
if [[ -n "$VALIDATION_RECORDS" || -n "$VALIDATION_EMBEDDINGS" ]]; then
  if [[ -z "$VALIDATION_RECORDS" || -z "$VALIDATION_EMBEDDINGS" ]]; then
    echo "Validation records and embeddings must be provided together" >&2
    exit 1
  fi
  if [[ ! -f "$VALIDATION_RECORDS" || ! -f "$VALIDATION_EMBEDDINGS" ]]; then
    echo "Missing validation records or embeddings" >&2
    exit 1
  fi
fi

mkdir -p "$OUT"
if [[ -n "$RESUME_SHA256" ]]; then
  if [[ ! -f "$OUT/last.pt" ]]; then
    echo "Missing expected resume checkpoint: $OUT/last.pt" >&2
    exit 1
  fi
  actual_resume_sha256="$(sha256sum "$OUT/last.pt" | awk '{print $1}')"
  if [[ "$actual_resume_sha256" != "$RESUME_SHA256" ]]; then
    echo "Resume checkpoint SHA256 mismatch: $actual_resume_sha256" >&2
    exit 1
  fi
fi
if [[ "$(id -u)" == "0" ]]; then
  owner="$(stat -c '%u:%g' "$N019_OFFICIAL_RUNS")"
  chown "$owner" "$OUT"
  trap 'chown -R "$owner" "$OUT" || true' EXIT
fi
export N019_PREFLIGHT_MANIFEST="$RECORDS"
bash "$ROOT/scripts/preflight_dcu_remote.sh"

{
  printf 'N019_VOICE_ROOT=%s\n' "$N019_VOICE_ROOT"
  printf 'N019_NPROC=%s\n' "$NPROC"
  printf 'N019_VOCODER_TOTAL_BATCH=%s\n' "$TOTAL_BATCH"
  printf 'N019_VOCODER_BATCH_PER_RANK=%s\n' "$BATCH_PER_RANK"
  printf 'N019_VOCODER_STEPS=%s\n' "$STEPS"
  printf 'N019_VOCODER_MAX_HOURS=%s\n' "$MAX_HOURS"
  printf 'N019_VOCODER_LR=%s\n' "$LR"
  printf 'N019_VOCODER_OPTIMIZER=%s\n' "$OPTIMIZER"
  printf 'N019_VOCODER_GRAD_CLIP_NORM=%s\n' "$GRAD_CLIP_NORM"
  printf 'N019_VOCODER_BF16=%s\n' "$BF16"
  printf 'N019_VOCODER_VALIDATION_INTERVAL=%s\n' "$VALIDATION_INTERVAL"
  printf 'N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL=%s\n' "$GENERATOR_SNAPSHOT_INTERVAL"
  printf 'N019_VOCODER_SELECTION_POLICY=%s\n' "$SELECTION_POLICY"
  printf 'N019_VOCODER_EARLY_STOP_MIN_STEPS=%s\n' "$EARLY_STOP_MIN_STEPS"
  printf 'N019_VOCODER_EARLY_STOP_PATIENCE=%s\n' "$EARLY_STOP_PATIENCE"
  printf 'N019_VOCODER_EARLY_STOP_MIN_DELTA=%s\n' "$EARLY_STOP_MIN_DELTA"
  printf 'N019_VOCODER_TYPE=%s\n' "$VOCODER_TYPE"
  printf 'N019_VOCODER_EMBEDDING_LEVEL=%s\n' "$EMBEDDING_LEVEL"
  printf 'N019_VOCODER_SPEAKER_EMBEDDING_SCALE=%s\n' "$SPEAKER_EMBEDDING_SCALE"
  printf 'N019_VOCODER_SPEAKER_SWAP_PROBABILITY=%s\n' "$SPEAKER_SWAP_PROBABILITY"
  printf 'N019_VOCODER_SPEAKER_SWAP_EMBEDDINGS=%s\n' "${SPEAKER_SWAP_EMBEDDINGS:-same-archive}"
  printf 'N019_VOCODER_SPEAKER_DIM=%s\n' "$SPEAKER_DIM"
  printf 'N019_VOCODER_RECORDS=%s\n' "$RECORDS"
  printf 'N019_VOCODER_EMBEDDINGS=%s\n' "$EMBEDDINGS"
  printf 'N019_VOCODER_VALIDATION_RECORDS=%s\n' "${VALIDATION_RECORDS:-training-monitor}"
  printf 'N019_VOCODER_VALIDATION_EMBEDDINGS=%s\n' "${VALIDATION_EMBEDDINGS:-training-monitor}"
  printf 'N019_VOCODER_OUT=%s\n' "$OUT"
  date -Is
  nvidia-smi 2>/dev/null || hy-smi || true
} | tee "$OUT/launch.txt"

RESUME_CONVERGED_ARGS=()
if [[ "${N019_VOCODER_RESUME_CONVERGED:-0}" == "1" ]]; then
  RESUME_CONVERGED_ARGS=(--resume-converged)
fi
ALLOW_RECIPE_CHANGE_ARGS=()
if [[ "${N019_VOCODER_ALLOW_RECIPE_CHANGE:-0}" == "1" ]]; then
  ALLOW_RECIPE_CHANGE_ARGS=(--allow-recipe-change)
fi
INIT_GENERATOR_ARGS=()
if [[ -n "${N019_VOCODER_INIT_GENERATOR:-}" ]]; then
  INIT_GENERATOR_ARGS=(--init-generator "$N019_VOCODER_INIT_GENERATOR")
  if [[ -n "${N019_VOCODER_INIT_GENERATOR_SHA256:-}" ]]; then
    INIT_GENERATOR_ARGS+=(
      --init-generator-sha256 "$N019_VOCODER_INIT_GENERATOR_SHA256"
    )
  fi
fi
VALIDATION_ARGS=()
if [[ -n "$VALIDATION_RECORDS" ]]; then
  VALIDATION_ARGS=(
    --validation-records "$VALIDATION_RECORDS"
    --validation-embeddings "$VALIDATION_EMBEDDINGS"
  )
fi
PRECISION_ARGS=()
if [[ "$BF16" == "1" ]]; then
  PRECISION_ARGS=(--bf16)
fi

python -m torch.distributed.run \
  --standalone \
  --nnodes=1 \
  --nproc_per_node="$NPROC" \
  -m n019.vocoder \
  --records "$RECORDS" \
  --embeddings "$EMBEDDINGS" \
  "${VALIDATION_ARGS[@]}" \
  --speaker-dim "$SPEAKER_DIM" \
  --embedding-level "$EMBEDDING_LEVEL" \
  --speaker-embedding-scale "$SPEAKER_EMBEDDING_SCALE" \
  --speaker-swap-probability "$SPEAKER_SWAP_PROBABILITY" \
  "${SPEAKER_SWAP_ARGS[@]}" \
  --out "$OUT" \
  --steps "$STEPS" \
  --lr "$LR" \
  --optimizer "$OPTIMIZER" \
  --grad-clip-norm "$GRAD_CLIP_NORM" \
  --max-hours "$MAX_HOURS" \
  --batch-size "$BATCH_PER_RANK" \
  --workers "$WORKERS" \
  --checkpoint-interval "$CHECKPOINT_INTERVAL" \
  --generator-snapshot-interval "$GENERATOR_SNAPSHOT_INTERVAL" \
  --keep-interval "$KEEP_INTERVAL" \
  --validation-interval "$VALIDATION_INTERVAL" \
  --selection-policy "$SELECTION_POLICY" \
  --early-stop-min-steps "$EARLY_STOP_MIN_STEPS" \
  --early-stop-patience "$EARLY_STOP_PATIENCE" \
  --early-stop-min-delta "$EARLY_STOP_MIN_DELTA" \
  "${RESUME_CONVERGED_ARGS[@]}" \
  "${ALLOW_RECIPE_CHANGE_ARGS[@]}" \
  "${INIT_GENERATOR_ARGS[@]}" \
  "${PRECISION_ARGS[@]}" \
  --device cuda
