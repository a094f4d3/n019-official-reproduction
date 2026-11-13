#!/bin/bash
#SBATCH --job-name=n019_ls360_spks_s
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=04:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"
cd "$ROOT"

: "${N019_DATA_SUFFIX:?Set N019_DATA_SUFFIX}"
: "${N019_ANON_OUT:?Set N019_ANON_OUT}"
: "${N019_LS360_SHARD_ROOT:?Set N019_LS360_SHARD_ROOT}"
: "${N019_SPEAKER_EMBEDDINGS:?Set N019_SPEAKER_EMBEDDINGS}"
: "${N019_RUN_NAME:?Set N019_RUN_NAME}"
: "${N019_VOCODER:?Set N019_VOCODER}"
: "${N019_VOCODER_SHA:?Set N019_VOCODER_SHA}"

SOURCE="${N019_SOURCE_MANIFEST:-$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360.jsonl}"
UNITS="${N019_UNIT_RECORDS:-$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_360/unit_records.jsonl}"
TARGET_MAP="${N019_TARGET_MAP:?Set N019_TARGET_MAP to the speaker-sampled LS360 map}"
TARGET_EMBEDDING_KEY="${N019_TARGET_EMBEDDING_KEY:-target_speaker}"
TARGET_EMBEDDING_MODE="${N019_TARGET_EMBEDDING_MODE:-speaker_sampled_mean32_shrink01}"
DURATION_MODE="${N019_DURATION_MODE:-pred}"
DURATION_EMBEDDING_KEY="${N019_DURATION_EMBEDDING_KEY:-target_id}"
DURATION_MODEL="${N019_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_pred_paperfix/best.pt}"
DURATION_EMBEDDINGS="${N019_DURATION_EMBEDDINGS:-}"
SHARDS="${N019_LS360_SHARDS:-4}"
EXPECTED_RECORDS=104014
S_EVAL_OUT="${N019_S_EVAL_OUT:-$N019_OFFICIAL_RUNS/privacy/$N019_RUN_NAME/s_eval}"

for required in \
  "$SOURCE" \
  "$UNITS" \
  "$TARGET_MAP" \
  "$N019_SPEAKER_EMBEDDINGS" \
  "$N019_VOCODER"; do
  test -f "$required" || {
    echo "Missing speaker-sampled S input: $required" >&2
    exit 1
  }
done
if [[ "$DURATION_MODE" != "orig" ]]; then
  test -f "$DURATION_MODEL" || {
    echo "Missing duration model: $DURATION_MODEL" >&2
    exit 1
  }
fi
if [[ "$DURATION_MODE" == "nt" || "$DURATION_MODE" == "ecapa" ]]; then
  test -f "$DURATION_EMBEDDINGS" || {
    echo "Missing duration embeddings: $DURATION_EMBEDDINGS" >&2
    exit 1
  }
fi
test "$(sha256sum "$N019_VOCODER" | awk '{print $1}')" = "$N019_VOCODER_SHA"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "suffix=$N019_DATA_SUFFIX"
echo "anon_out=$N019_ANON_OUT"
echo "shard_root=$N019_LS360_SHARD_ROOT"
echo "target_map=$TARGET_MAP"
echo "speaker_embeddings=$N019_SPEAKER_EMBEDDINGS"
echo "target_embedding_key=$TARGET_EMBEDDING_KEY"
echo "target_embedding_mode=$TARGET_EMBEDDING_MODE"
echo "duration_mode=$DURATION_MODE"
echo "duration_model=$DURATION_MODEL"
echo "duration_embeddings=$DURATION_EMBEDDINGS"
echo "duration_embedding_key=$DURATION_EMBEDDING_KEY"
echo "vocoder=$N019_VOCODER sha256=$N019_VOCODER_SHA"
echo "s_eval_out=$S_EVAL_OUT"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

python "$ROOT/scripts/prepare_ls360_anonymise_shards.py" \
  --source-manifest "$SOURCE" \
  --unit-records "$UNITS" \
  --target-map "$TARGET_MAP" \
  --out-dir "$N019_LS360_SHARD_ROOT" \
  --shards "$SHARDS" \
  --expected-records "$EXPECTED_RECORDS"

mkdir -p "$N019_ANON_OUT"
for ((index = 0; index < SHARDS; index++)); do
  shard_dir="$N019_LS360_SHARD_ROOT/shard_$index"
  mkdir -p "$shard_dir/anon"
  N019_SOURCE_MANIFEST="$shard_dir/manifest.jsonl" \
  N019_UNIT_RECORDS="$shard_dir/unit_records.jsonl" \
  N019_TARGET_MAP="$shard_dir/target_map.jsonl" \
  N019_ANON_OUT="$shard_dir/anon" \
  N019_SKIP_VPC_EXPORT=1 \
  N019_DATA_SUFFIX="$N019_DATA_SUFFIX" \
  N019_DURATION_MODE="$DURATION_MODE" \
  N019_DURATION_MODEL="$DURATION_MODEL" \
  N019_DURATION_EMBEDDINGS="$DURATION_EMBEDDINGS" \
  N019_DURATION_EMBEDDING_KEY="$DURATION_EMBEDDING_KEY" \
  N019_VOCODER_TYPE=nt \
  N019_VOCODER="$N019_VOCODER" \
  N019_VOCODER_EMBEDDINGS="$N019_SPEAKER_EMBEDDINGS" \
  N019_TARGET_EMBEDDING_KEY="$TARGET_EMBEDDING_KEY" \
  N019_TARGET_EMBEDDING_MODE="$TARGET_EMBEDDING_MODE" \
    bash "$ROOT/scripts/anonymize_ls360_remote.sh"
done

python "$ROOT/scripts/merge_ls360_anonymisation_shards.py" \
  --source-manifest "$SOURCE" \
  --shard-root "$N019_LS360_SHARD_ROOT" \
  --shards "$SHARDS" \
  --out-dir "$N019_ANON_OUT" \
  --expected-records "$EXPECTED_RECORDS"

python -m n019.export_vpc_anon \
  --vpc-data-dir "$N019_OFFICIAL_DATA/vpc/data" \
  --anon-manifest "$N019_ANON_OUT/anon.jsonl" \
  --suffix "$N019_DATA_SUFFIX" \
  --dataset-name train-clean-360 \
  --overwrite-missing

python "$ROOT/scripts/verify_anonymized_outputs.py" \
  --source-manifest "$SOURCE" \
  --out-dir "$N019_ANON_OUT" \
  --vpc-suffix-dir "$N019_OFFICIAL_DATA/vpc/data/train-clean-360$N019_DATA_SUFFIX" \
  --duration-mode pred \
  --vocoder-type nt \
  --expected-records "$EXPECTED_RECORDS" \
  --out "$N019_ANON_OUT/verification.json"

N019_DATA_SUFFIX="$N019_DATA_SUFFIX" \
N019_RUN_NAME="$N019_RUN_NAME" \
N019_S_EVAL_OUT="$S_EVAL_OUT" \
  bash "$ROOT/scripts/run_s_eval_remote.sh"

sha256sum \
  "$TARGET_MAP" \
  "$N019_SPEAKER_EMBEDDINGS" \
  "$N019_ANON_OUT/anon.jsonl" \
  "$N019_ANON_OUT/verification.json" \
  "$N019_OFFICIAL_DATA/vpc/data/train-clean-360$N019_DATA_SUFFIX/wav.scp" \
  "$S_EVAL_OUT/s_metrics.json"
echo "LS360_SPEAKER_SAMPLED_S_COMPLETE suffix=$N019_DATA_SUFFIX out=$S_EVAL_OUT"
