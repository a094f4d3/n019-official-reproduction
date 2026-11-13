#!/bin/bash
#SBATCH --job-name=n019_fullmean1160_s
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

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

export N019_OFFICIAL_ROOT="$ROOT"
export N019_CANDIDATE_ROOT="$N019_OFFICIAL_RUNS/privacy/fullmean1160_du_pred_nt_s_20261112"
export TMPDIR="$N019_CANDIDATE_ROOT/tmp"
mkdir -p "$TMPDIR"
export N019_DATA_SUFFIX="_n019_fullmean1160_20261112"
export N019_RUN_NAME="fullmean1160_du_pred_nt_s_20261112"
export N019_ANON_OUT="$N019_CANDIDATE_ROOT/anonymised/ls360"
export N019_LS360_SHARD_ROOT="$N019_VOICE_ROOT/tmp/n019_fullmean1160_ls360_shards_20261112"
export N019_SPEAKER_EMBEDDINGS="$N019_OFFICIAL_DATA/processed/embeddings/target_speaker_fullmean1160_20261112/nt_speaker_embeddings.npz"
export N019_VOCODER="$N019_VOICE_ROOT/tmp/n019_model_soup_round2_candidates_20261110/generator_avg_soup2_quad_w40_30_20_10.pt"
export N019_VOCODER_SHA="ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
export N019_TARGET_MAP="$N019_OFFICIAL_DATA/processed/targets/full_other500_1160_seed20261102/librispeech_train_clean_360_target_map.jsonl"
export N019_TARGET_EMBEDDING_KEY="target_speaker"
export N019_TARGET_EMBEDDING_MODE="speaker_mean_l2"
export N019_DURATION_MODE="pred"
export N019_S_EVAL_OUT="$N019_CANDIDATE_ROOT/s_eval"
export N019_ASV_CONFIG="$ROOT/configs/eval_paper_test_only_post_nw0.yaml"

exec bash -x "$ROOT/hpc/n019_ls360_speaker_sampled_s_pipeline_hpc.slurm"
