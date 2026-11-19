#!/usr/bin/env bash
#SBATCH --job-name=n019_ntecres025s
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=04:00:00
#SBATCH --output=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_ntecres025s_%j.out
#SBATCH --error=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_ntecres025s_%j.err

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
mkdir -p "$N019_OFFICIAL_LOGS" "$N019_OFFICIAL_RUNS"
export TMPDIR="/dev/shm/n019_ntecres025s_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

SOURCE="$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360_d10paths_20261117.jsonl"
UNITS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/librispeech_train_clean_360/unit_records.jsonl
TARGET_MAP="$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_map_utterance.jsonl"
TARGET_EMBEDDINGS="$N019_OFFICIAL_DATA/processed/embeddings/nt_ecapa_residual_all1158_20261117/residual_0p25.npz"
DURATION_MODEL=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt
VOCODER=/public/home/a094f4d10/voice_projects/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt
SUFFIX="_n019_ntecres025_20261117"
RUN_NAME="ntecres025_20261117"
SHARD_ROOT="$N019_OFFICIAL_RUNS/privacy/${RUN_NAME}_shards"
ANON_OUT="$N019_OFFICIAL_RUNS/privacy/${RUN_NAME}_ls360/anonymised"
S_EVAL_OUT="$N019_OFFICIAL_RUNS/privacy/${RUN_NAME}_s"
EXPECTED_RECORDS=104014
SHARDS=4

for required in \
  "$SOURCE" "$UNITS" "$TARGET_MAP" "$TARGET_EMBEDDINGS" \
  "$DURATION_MODEL" "$VOCODER" \
  "$N019_OFFICIAL_DATA/vpc/data/train-clean-360/wav.scp"; do
  test -s "$required" || {
    echo "Missing residual0.25 LS360 input: $required" >&2
    exit 1
  }
done

test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = "8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"
test "$(wc -l < "$SOURCE")" = "$EXPECTED_RECORDS"
test "$(wc -l < "$UNITS")" = "$EXPECTED_RECORDS"
test "$(wc -l < "$TARGET_MAP")" = "$EXPECTED_RECORDS"

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=official LS360 E-VPC S for NT+ECAPA residual strength 0.25"
echo "suffix=$SUFFIX shards=$SHARDS expected_records=$EXPECTED_RECORDS"
echo "target_embeddings=$TARGET_EMBEDDINGS sha256=$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')"
echo "duration=$DURATION_MODEL"
echo "vocoder=$VOCODER"
echo "wall=4h expected=3.0 worst=4.0 card-hours"

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
  N019_DURATION_MODE=pred \
  N019_DURATION_MODEL="$DURATION_MODEL" \
  N019_VOCODER_TYPE=nt \
  N019_VOCODER="$VOCODER" \
  N019_VOCODER_EMBEDDINGS="$TARGET_EMBEDDINGS" \
  N019_TARGET_EMBEDDING_KEY=target_speaker \
  N019_TARGET_EMBEDDING_MODE=speaker_mean_l2 \
  N019_SPEAKER_EMBEDDING_SCALE=1.0 \
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
  --duration-mode pred \
  --vocoder-type nt \
  --expected-records "$EXPECTED_RECORDS" \
  --out "$ANON_OUT/verification.json"

N019_DATA_SUFFIX="$SUFFIX" \
N019_RUN_NAME="$RUN_NAME" \
N019_S_EVAL_OUT="$S_EVAL_OUT" \
  bash "$ROOT/scripts/run_s_eval_remote.sh"

sha256sum \
  "$TARGET_EMBEDDINGS" \
  "$DURATION_MODEL" \
  "$ANON_OUT/anon.jsonl" \
  "$ANON_OUT/verification.json" \
  "$N019_OFFICIAL_DATA/vpc/data/train-clean-360$SUFFIX/wav.scp" \
  "$S_EVAL_OUT/s_metrics.json"
echo "N019_NT_ECAPA_RESIDUAL_025_S_COMPLETE out=$S_EVAL_OUT"
