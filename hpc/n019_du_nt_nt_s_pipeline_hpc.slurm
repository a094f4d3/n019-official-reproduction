#!/bin/bash
#SBATCH --job-name=n019_du_nt_nt_s
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=05:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

RUN_ROOT="${N019_DU_NT_RUN_ROOT:-$N019_OFFICIAL_RUNS/privacy/du_nt_nt_s_20261111}"
STAGED="${N019_DU_NT_STAGED:-$N019_OFFICIAL_DATA/processed/targets/du_nt_nt_20261111}"
SUFFIX="${N019_DATA_SUFFIX:-_n019_du_nt_nt_20261111}"
VOCODER="${N019_VOCODER:-$HOME/voice_projects/tmp/n019_privacy_fix_20261111/generator_soup2.pt}"
VOCODER_SHA="${N019_VOCODER_SHA:-ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6}"
DURATION_MODEL="${N019_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_nt_main/best.pt}"
LS360_TARGET_EMBEDDINGS="${N019_LS360_TARGET_EMBEDDINGS:-$STAGED/target_speaker_mean32_all1158_shrink01.npz}"
TEST_TARGET_EMBEDDINGS="${N019_TEST_TARGET_EMBEDDINGS:-$STAGED/test_target_speaker_mean32_954_shrink01.npz}"
TEST_TARGET_MAP="${N019_TEST_TARGET_MAP:-$STAGED/libri_test_target_map_speaker_available_seed20261102.jsonl}"
LS360_TARGET_MAP="${N019_LS360_TARGET_MAP:-$STAGED/librispeech_train_clean_360_target_map_speaker_available_seed20261102.jsonl}"
LS360_SOURCE_MANIFEST="${N019_SOURCE_MANIFEST:-$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360_d5read_20261111.jsonl}"
LS360_UNIT_RECORDS="${N019_UNIT_RECORDS:-$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_360/unit_records_d5read_20261111.jsonl}"

mkdir -p "$RUN_ROOT" "$N019_OFFICIAL_LOGS"
echo "user=$(id -un) host=$(hostname) date=$(date -Is) job=${SLURM_JOB_ID}"
echo "run_root=$RUN_ROOT suffix=$SUFFIX"
echo "vocoder=$VOCODER sha256=$VOCODER_SHA"
echo "duration_model=$DURATION_MODEL"
echo "ls360_target_embeddings=$LS360_TARGET_EMBEDDINGS"
echo "test_target_embeddings=$TEST_TARGET_EMBEDDINGS"
echo "test_target_map=$TEST_TARGET_MAP"
echo "ls360_target_map=$LS360_TARGET_MAP"
echo "ls360_source_manifest=$LS360_SOURCE_MANIFEST"
echo "ls360_unit_records=$LS360_UNIT_RECORDS"

for required in \
  "$VOCODER" \
  "$DURATION_MODEL" \
  "$LS360_TARGET_EMBEDDINGS" \
  "$TEST_TARGET_EMBEDDINGS" \
  "$TEST_TARGET_MAP" \
  "$LS360_TARGET_MAP" \
  "$LS360_SOURCE_MANIFEST" \
  "$LS360_UNIT_RECORDS"; do
  test -f "$required" || {
    echo "Missing DU-nt-nt input: $required" >&2
    exit 1
  }
done
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "$VOCODER_SHA"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

export N019_LIBRI_TEST_TARGET_MAP="$TEST_TARGET_MAP"
export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA="$(sha256sum "$N019_OFFICIAL_DATA/processed/manifests/libri_test.jsonl" | awk '{print $1}')"
export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$TEST_TARGET_EMBEDDINGS"
export N019_LIBRI_TEST_TARGET_EMBEDDING_KEY=target_speaker
export N019_LIBRI_TEST_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1
export N019_LIBRI_TEST_DURATION_MODE=nt
export N019_LIBRI_TEST_DURATION_MODEL="$DURATION_MODEL"
export N019_LIBRI_TEST_DURATION_EMBEDDINGS="$TEST_TARGET_EMBEDDINGS"
export N019_LIBRI_TEST_DURATION_EMBEDDING_KEY=target_speaker
export N019_LIBRI_TEST_EXPECTED_DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
export N019_LIBRI_TEST_VOCODER="$VOCODER"
export N019_LIBRI_TEST_EXPECTED_VOCODER_SHA="$VOCODER_SHA"
export N019_LIBRI_TEST_ANON_OUT="$RUN_ROOT/anonymised/libri_test"
export N019_LIBRI_TEST_SUFFIX="$SUFFIX"
export N019_LIBRI_TEST_VERIFY="$RUN_ROOT/verify_libri_test.json"
bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

export N019_TARGET_MAP="$LS360_TARGET_MAP"
export N019_SOURCE_MANIFEST="$LS360_SOURCE_MANIFEST"
export N019_UNIT_RECORDS="$LS360_UNIT_RECORDS"
export N019_SPEAKER_EMBEDDINGS="$LS360_TARGET_EMBEDDINGS"
export N019_TARGET_EMBEDDING_KEY=target_speaker
export N019_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1
export N019_DURATION_MODE=nt
export N019_DURATION_MODEL="$DURATION_MODEL"
export N019_DURATION_EMBEDDINGS="$LS360_TARGET_EMBEDDINGS"
export N019_DURATION_EMBEDDING_KEY=target_speaker
export N019_LS360_SHARD_ROOT="$RUN_ROOT/shards"
export N019_ANON_OUT="$RUN_ROOT/anonymised/ls360"
export N019_S_EVAL_OUT="$RUN_ROOT/s_eval"
export N019_RUN_NAME="du_nt_nt_s_20261111"
export N019_VOCODER="$VOCODER"
export N019_VOCODER_SHA="$VOCODER_SHA"
export N019_DATA_SUFFIX="$SUFFIX"
bash "$ROOT/hpc/n019_ls360_speaker_sampled_s_pipeline_hpc.slurm"

sha256sum \
  "$TEST_TARGET_MAP" \
  "$LS360_TARGET_MAP" \
  "$LS360_TARGET_EMBEDDINGS" \
  "$TEST_TARGET_EMBEDDINGS" \
  "$DURATION_MODEL" \
  "$VOCODER" \
  "$RUN_ROOT/anonymised/libri_test/anon.jsonl" \
  "$RUN_ROOT/anonymised/ls360/anon.jsonl" \
  "$RUN_ROOT/s_eval/s_metrics.json"
echo "DU_NT_NT_S_COMPLETE run_root=$RUN_ROOT suffix=$SUFFIX"
