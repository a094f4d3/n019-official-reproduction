#!/bin/bash
#SBATCH --job-name=n019_dunntutt_s
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

ROOT="/public/home/a094f4d10/voice_projects/code/n019_official"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="/public/home/a094f4d10/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"
cd "$ROOT"
export TMPDIR="/dev/shm/n019_dunntutt_s_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

SOURCE="/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/librispeech_train_clean_360_d10paths_20261117.jsonl"
UNITS="/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/librispeech_train_clean_360/unit_records.jsonl"
TARGET_MAP="/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/librispeech_train_clean_360_target_map_utterance.jsonl"
TARGET_EMBEDDINGS="/public/home/a094f4d6/voice_projects/data/n019_official/processed/embeddings/librispeech_train_clean_360_target_nt_utterance/nt_utterance_embeddings.npz"
DURATION_MODEL="/public/home/a094f4d6/voice_projects/runs/n019_official/duration_nt_main/best.pt"
VOCODER="/public/home/a094f4d6/voice_projects/tmp/n019_privacy_fix_20261111/generator_soup2.pt"
VOCODER_SHA="ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"

SUFFIX="_n019_du_nt_nt_utt_20261117"
RUN_NAME="du_nt_nt_utt_20261117"
SHARD_ROOT="$N019_OFFICIAL_RUNS/privacy/${RUN_NAME}_shards"
ANON_OUT="$N019_OFFICIAL_RUNS/privacy/${RUN_NAME}_ls360/anonymised"
S_EVAL_OUT="$N019_OFFICIAL_RUNS/privacy/${RUN_NAME}_s"
EXPECTED_RECORDS=104014
SHARDS=4

for required in \
  "$SOURCE" \
  "$UNITS" \
  "$TARGET_MAP" \
  "$TARGET_EMBEDDINGS" \
  "$DURATION_MODEL" \
  "$VOCODER"; do
  test -f "$required" || {
    echo "Missing DU-nt-nt LS360 input: $required" >&2
    exit 1
  }
done
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "$VOCODER_SHA"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=LS360 E-VPC S for DU-nt-nt target-utterance conditioning"
echo "suffix=$SUFFIX shards=$SHARDS expected_records=$EXPECTED_RECORDS"
echo "target_embeddings=$TARGET_EMBEDDINGS"
echo "duration_model=$DURATION_MODEL"
echo "vocoder=$VOCODER sha256=$VOCODER_SHA"
echo "anon_out=$ANON_OUT s_eval_out=$S_EVAL_OUT"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

python "$ROOT/scripts/prepare_ls360_anonymise_shards.py" \
  --source-manifest "$SOURCE" \
  --unit-records "$UNITS" \
  --target-map "$TARGET_MAP" \
  --out-dir "$SHARD_ROOT" \
  --shards "$SHARDS" \
  --expected-records "$EXPECTED_RECORDS"

mkdir -p "$ANON_OUT"
for ((index = 0; index < SHARDS; index++)); do
  shard_dir="$SHARD_ROOT/shard_$index"
  mkdir -p "$shard_dir/anon"
  N019_SOURCE_MANIFEST="$shard_dir/manifest.jsonl" \
  N019_UNIT_RECORDS="$shard_dir/unit_records.jsonl" \
  N019_TARGET_MAP="$shard_dir/target_map.jsonl" \
  N019_ANON_OUT="$shard_dir/anon" \
  N019_SKIP_VPC_EXPORT=1 \
  N019_DATA_SUFFIX="$SUFFIX" \
  N019_DURATION_MODE=nt \
  N019_DURATION_MODEL="$DURATION_MODEL" \
  N019_DURATION_EMBEDDINGS="$TARGET_EMBEDDINGS" \
  N019_DURATION_EMBEDDING_KEY=target_id \
  N019_VOCODER_TYPE=nt \
  N019_VOCODER="$VOCODER" \
  N019_VOCODER_EMBEDDINGS="$TARGET_EMBEDDINGS" \
  N019_TARGET_EMBEDDING_KEY=target_id \
  N019_TARGET_EMBEDDING_MODE=utterance \
    bash "$ROOT/scripts/anonymize_ls360_remote.sh"
done

python "$ROOT/scripts/merge_ls360_anonymisation_shards.py" \
  --source-manifest "$SOURCE" \
  --shard-root "$SHARD_ROOT" \
  --shards "$SHARDS" \
  --out-dir "$ANON_OUT" \
  --expected-records "$EXPECTED_RECORDS"

python -m n019.export_vpc_anon \
  --vpc-data-dir "$N019_OFFICIAL_DATA/vpc/data" \
  --anon-manifest "$ANON_OUT/anon.jsonl" \
  --suffix "$SUFFIX" \
  --dataset-name train-clean-360 \
  --overwrite-missing

python "$ROOT/scripts/verify_anonymized_outputs.py" \
  --source-manifest "$SOURCE" \
  --out-dir "$ANON_OUT" \
  --vpc-suffix-dir "$N019_OFFICIAL_DATA/vpc/data/train-clean-360$SUFFIX" \
  --duration-mode nt \
  --vocoder-type nt \
  --expected-records "$EXPECTED_RECORDS" \
  --out "$ANON_OUT/verification.json"

N019_DATA_SUFFIX="$SUFFIX" \
N019_RUN_NAME="$RUN_NAME" \
N019_S_EVAL_OUT="$S_EVAL_OUT" \
  bash "$ROOT/scripts/run_s_eval_remote.sh"

sha256sum \
  "$TARGET_EMBEDDINGS" \
  "$ANON_OUT/anon.jsonl" \
  "$ANON_OUT/verification.json" \
  "$N019_OFFICIAL_DATA/vpc/data/train-clean-360$SUFFIX/wav.scp" \
  "$S_EVAL_OUT/s_metrics.json"
echo "N019_DU_NT_NT_UTT_S_COMPLETE suffix=$SUFFIX out=$S_EVAL_OUT"
