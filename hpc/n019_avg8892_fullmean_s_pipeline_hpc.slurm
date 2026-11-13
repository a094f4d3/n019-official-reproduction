#!/usr/bin/env bash
#SBATCH --job-name=n019_avg8892_fullmean_s
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=04:00:00
#SBATCH --exclude=f11r1n01,f11r2n13
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
export TMPDIR="/dev/shm/n019_avg8892_s_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

RUN_ROOT="$N019_OFFICIAL_RUNS/privacy/avg8892_fullmean_s_20261112"
TARGET_ROOT="$N019_OFFICIAL_DATA/processed/targets/full_other500_1160_seed20261102"
TEST_MAP="$TARGET_ROOT/libri_test_target_map.jsonl"
LS360_MAP="$TARGET_ROOT/librispeech_train_clean_360_target_map.jsonl"
TARGET_EMB_ROOT="$N019_OFFICIAL_DATA/processed/embeddings/target_speaker_fullmean1160_20261112"
TEST_TARGET_EMB="$TARGET_EMB_ROOT/test_941.npz"
LS360_TARGET_EMB="$TARGET_EMB_ROOT/nt_speaker_embeddings.npz"
VOCODER="$N019_VOICE_ROOT/tmp/n019_d5_snapshots_20261110/generator_avg_88_92_effnorm.pt"
VOCODER_SHA="fafe5982588bea492dd761f1c2d51cc925474503a4f158cf1680667b2286ded8"
DURATION_MODEL="$N019_OFFICIAL_RUNS/duration_pred_paperfix/best.pt"
SUFFIX="_n019_avg8892_fullmean_20261112"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "purpose=avg88_92 checkpoint E-VPC S comparison at fixed fullmean target"
echo "run_root=$RUN_ROOT suffix=$SUFFIX"
echo "vocoder=$VOCODER sha256=$VOCODER_SHA"

for required in \
  "$TEST_MAP" "$LS360_MAP" "$TEST_TARGET_EMB" "$LS360_TARGET_EMB" \
  "$VOCODER" "$DURATION_MODEL" \
  "$N019_OFFICIAL_DATA/processed/manifests/libri_test.jsonl" \
  "$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360.jsonl" \
  "$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_360/unit_records.jsonl"; do
  test -f "$required" || {
    echo "Missing avg88_92 S input: $required" >&2
    exit 1
  }
done
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "$VOCODER_SHA"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

export N019_LIBRI_TEST_TARGET_MAP="$TEST_MAP"
export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA="$(sha256sum "$N019_OFFICIAL_DATA/processed/manifests/libri_test.jsonl" | awk '{print $1}')"
export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$TEST_TARGET_EMB"
export N019_LIBRI_TEST_TARGET_EMBEDDING_KEY=target_speaker
export N019_LIBRI_TEST_TARGET_EMBEDDING_MODE=speaker_mean_l2
export N019_LIBRI_TEST_DURATION_MODE=pred
export N019_LIBRI_TEST_DURATION_MODEL="$DURATION_MODEL"
export N019_LIBRI_TEST_EXPECTED_DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
export N019_LIBRI_TEST_VOCODER="$VOCODER"
export N019_LIBRI_TEST_EXPECTED_VOCODER_SHA="$VOCODER_SHA"
export N019_LIBRI_TEST_ANON_OUT="$RUN_ROOT/anonymised/libri_test"
export N019_LIBRI_TEST_SUFFIX="$SUFFIX"
export N019_LIBRI_TEST_VERIFY="$RUN_ROOT/verify_libri_test.json"
bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

export N019_SOURCE_MANIFEST="$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360.jsonl"
export N019_UNIT_RECORDS="$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_360/unit_records.jsonl"
export N019_TARGET_MAP="$LS360_MAP"
export N019_SPEAKER_EMBEDDINGS="$LS360_TARGET_EMB"
export N019_TARGET_EMBEDDING_KEY=target_speaker
export N019_TARGET_EMBEDDING_MODE=speaker_mean_l2
export N019_DURATION_MODE=pred
export N019_DURATION_MODEL="$DURATION_MODEL"
export N019_LS360_SHARD_ROOT="$RUN_ROOT/shards"
export N019_LS360_SHARDS=4
export N019_ANON_OUT="$RUN_ROOT/anonymised/ls360"
export N019_S_EVAL_OUT="$RUN_ROOT/s_eval"
export N019_RUN_NAME="avg8892_fullmean_s_20261112"
export N019_VOCODER="$VOCODER"
export N019_VOCODER_SHA="$VOCODER_SHA"
export N019_DATA_SUFFIX="$SUFFIX"
bash "$ROOT/hpc/n019_ls360_speaker_sampled_s_pipeline_hpc.slurm"

sha256sum \
  "$TEST_MAP" "$LS360_MAP" "$TEST_TARGET_EMB" "$LS360_TARGET_EMB" \
  "$RUN_ROOT/anonymised/libri_test/anon.jsonl" \
  "$RUN_ROOT/anonymised/ls360/anon.jsonl" \
  "$RUN_ROOT/s_eval/s_metrics.json"
echo "N019_AVG8892_FULLMEAN_S_COMPLETE out=$RUN_ROOT/s_eval"
