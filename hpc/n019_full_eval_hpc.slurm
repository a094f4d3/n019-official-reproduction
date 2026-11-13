#!/bin/bash
#SBATCH --job-name=n019_full_eval
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

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official_diag_20261110}"
export N019_OFFICIAL_ROOT="$ROOT"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

echo "user=$(id -un) host=$(hostname) date=$(date -Is) job=${SLURM_JOB_ID}"
echo "label=${N019_EVAL_LABEL:-unset}"
echo "vocoder=${N019_EVAL_VOCODER:-unset}"
echo "target_embeddings=${N019_EVAL_TARGET_EMBEDDINGS:-unset}"

bash -x "$ROOT/scripts/run_full_eval_param_ai.sh"
