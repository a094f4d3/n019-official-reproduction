#!/bin/bash
#SBATCH --job-name=n019_fullmean1160_eval
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=02:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

export N019_OFFICIAL_ROOT="$ROOT"
export N019_CANDIDATE_ROOT="$N019_OFFICIAL_RUNS/privacy/fullmean1160_du_pred_nt_20261112"
export TMPDIR="$N019_CANDIDATE_ROOT/tmp"
mkdir -p "$TMPDIR"
export N019_EVAL_LABEL="fullmean1160_20261112"
export N019_EVAL_STEPS=92000
export N019_EVAL_VOCODER="$N019_VOICE_ROOT/tmp/n019_model_soup_round2_candidates_20261110/generator_avg_soup2_quad_w40_30_20_10.pt"
export N019_EVAL_VOC_SHA="ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
export N019_EVAL_TARGET_EMBEDDINGS="$N019_OFFICIAL_DATA/processed/embeddings/target_speaker_fullmean1160_20261112/test_941.npz"
export N019_EVAL_TARGET_EMBEDDING_KEY="target_speaker"
export N019_EVAL_TARGET_EMBEDDING_MODE="speaker_mean_l2"
export N019_LIBRI_TEST_TARGET_MAP="$N019_OFFICIAL_DATA/processed/targets/full_other500_1160_seed20261102/libri_test_target_map.jsonl"
export N019_LIBRI_TEST_TARGET_KEY="target_speaker"
export N019_EVAL_ANON_OUT="$N019_CANDIDATE_ROOT/anonymised/libri_test"
export N019_EVAL_OUT="$N019_CANDIDATE_ROOT/eval"

exec bash -x "$ROOT/scripts/run_full_eval_param_ai.sh"
