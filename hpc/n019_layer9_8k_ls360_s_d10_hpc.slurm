#!/bin/bash
#SBATCH --job-name=n019_l9_8k_s
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
export TMPDIR="/dev/shm/n019_layer9_s_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

RUN_ROOT="$N019_OFFICIAL_RUNS/privacy/layer9_8k_s_20261117"
UNITS="$HOME/voice_projects/data/n019_official/processed/units/librispeech_train_clean_360_layer9_aligned_20261117/unit_records.jsonl"
SOURCE="$HOME/voice_projects/data/n019_official/processed/manifests/librispeech_train_clean_360_d10paths_20261117.jsonl"
TARGET_MAP="/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/librispeech_train_clean_360_target_map_utterance.jsonl"
TARGET_EMBEDDINGS="/public/home/a094f4d6/voice_projects/tmp/n019_privacy_fix_20261111/target_speaker_mean32_all1158_shrink01.npz"
VOCODER="$N019_OFFICIAL_RUNS/vocoder_nt_layer9_aligned_pilot_20261116/snapshots/generator_step00008000.pt"
VOCODER_SHA="39aeebe086700a3b18a29aa1f9ec354575b0a60aa86dc328c0a2ed2543559b66"
DURATION_MODEL="$N019_OFFICIAL_RUNS/duration_pred_layer9_aligned_20261116/best.pt"
DURATION_SHA="c84fe19ed8f9e31199ac6dd1926e2d565e8a4179c90f04411f55ced0c1191d5b"
SUFFIX="_n019_layer9_8k_s_20261117"

for required in "$UNITS" "$SOURCE" "$TARGET_MAP" "$TARGET_EMBEDDINGS" "$VOCODER" "$DURATION_MODEL"; do
  test -s "$required" || {
    echo "Missing layer-9 S input: $required" >&2
    exit 1
  }
done
test "$(wc -l < "$UNITS")" = 104014
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "$VOCODER_SHA"
test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = "$DURATION_SHA"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "purpose=official VPC E-VPC S screen for layer-9 8k"
echo "run_root=$RUN_ROOT suffix=$SUFFIX"
echo "units=$UNITS"
echo "vocoder=$VOCODER sha256=$VOCODER_SHA"
echo "duration=$DURATION_MODEL sha256=$DURATION_SHA"

export N019_SOURCE_MANIFEST="$SOURCE"
export N019_UNIT_RECORDS="$UNITS"
export N019_TARGET_MAP="$TARGET_MAP"
export N019_SPEAKER_EMBEDDINGS="$TARGET_EMBEDDINGS"
export N019_TARGET_EMBEDDING_KEY=target_speaker
export N019_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1
export N019_DURATION_MODE=pred
export N019_DURATION_MODEL="$DURATION_MODEL"
export N019_LS360_SHARD_ROOT="$RUN_ROOT/shards"
export N019_LS360_SHARDS=4
export N019_ANON_OUT="$RUN_ROOT/anonymised"
export N019_S_EVAL_OUT="$RUN_ROOT/s_eval"
export N019_RUN_NAME="layer9_8k_s_20261117"
export N019_VOCODER="$VOCODER"
export N019_VOCODER_SHA="$VOCODER_SHA"
export N019_DATA_SUFFIX="$SUFFIX"

bash "$ROOT/hpc/n019_ls360_speaker_sampled_s_pipeline_hpc.slurm"

sha256sum \
  "$UNITS" \
  "$RUN_ROOT/anonymised/anon.jsonl" \
  "$RUN_ROOT/anonymised/verification.json" \
  "$N019_OFFICIAL_DATA/vpc/data/train-clean-360$SUFFIX/wav.scp" \
  "$RUN_ROOT/s_eval/s_metrics.json"
echo "N019_LAYER9_8K_LS360_S_COMPLETE out=$RUN_ROOT/s_eval"
