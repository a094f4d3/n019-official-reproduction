#!/usr/bin/env bash
#SBATCH --job-name=n019_source_s_diag
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
export TMPDIR="/dev/shm/n019_source_s_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

RUN_ROOT="$N019_OFFICIAL_RUNS/source_reconstruction_diag_20261112"
TEST_MAP="$RUN_ROOT/target_maps/libri_test_source_target_map.jsonl"
LS360_MAP="$RUN_ROOT/target_maps/librispeech_train_clean_360_source_target_map.jsonl"
TEST_EMB="$RUN_ROOT/embeddings/test/nt_speaker_embeddings.npz"
LS360_EMB="$RUN_ROOT/embeddings/ls360/nt_speaker_embeddings.npz"
VOCODER="$N019_VOICE_ROOT/tmp/n019_model_soup_round2_candidates_20261110/generator_avg_soup2_quad_w40_30_20_10.pt"
VOCODER_SHA="ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
DURATION_MODEL="$N019_OFFICIAL_RUNS/duration_pred_paperfix/best.pt"
SUFFIX="_n019_source_recon_diag_20261112"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "purpose=source-reconstruction E-VPC S diagnostic only"
echo "run_root=$RUN_ROOT suffix=$SUFFIX"
echo "vocoder=$VOCODER sha256=$VOCODER_SHA"

for required in \
  "$TEST_MAP" "$LS360_MAP" "$TEST_EMB" "$LS360_EMB" \
  "$VOCODER" "$DURATION_MODEL" \
  "$N019_OFFICIAL_DATA/processed/manifests/libri_test.jsonl" \
  "$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360.jsonl" \
  "$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_360/unit_records.jsonl"; do
  test -f "$required" || {
    echo "Missing source-reconstruction input: $required" >&2
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
export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$TEST_EMB"
export N019_LIBRI_TEST_TARGET_EMBEDDING_KEY=target_speaker
export N019_LIBRI_TEST_TARGET_EMBEDDING_MODE=source_speaker_mean_l2
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
export N019_SPEAKER_EMBEDDINGS="$LS360_EMB"
export N019_TARGET_EMBEDDING_KEY=target_speaker
export N019_TARGET_EMBEDDING_MODE=source_speaker_mean_l2
export N019_DURATION_MODE=pred
export N019_DURATION_MODEL="$DURATION_MODEL"
export N019_LS360_SHARD_ROOT="$RUN_ROOT/shards"
export N019_LS360_SHARDS=4
export N019_ANON_OUT="$RUN_ROOT/anonymised/ls360"
export N019_S_EVAL_OUT="$RUN_ROOT/s_eval"
export N019_RUN_NAME="source_reconstruction_diag_20261112"
export N019_VOCODER="$VOCODER"
export N019_VOCODER_SHA="$VOCODER_SHA"
export N019_DATA_SUFFIX="$SUFFIX"
bash "$ROOT/hpc/n019_ls360_speaker_sampled_s_pipeline_hpc.slurm"

sha256sum \
  "$TEST_MAP" "$LS360_MAP" "$TEST_EMB" "$LS360_EMB" \
  "$RUN_ROOT/anonymised/libri_test/anon.jsonl" \
  "$RUN_ROOT/anonymised/ls360/anon.jsonl" \
  "$RUN_ROOT/s_eval/s_metrics.json"
echo "N019_SOURCE_RECONSTRUCTION_S_COMPLETE out=$RUN_ROOT/s_eval"
