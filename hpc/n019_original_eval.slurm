#!/bin/bash
#SBATCH --job-name=n019_orig_eval
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=dcu:1
#SBATCH --mem=24G
#SBATCH --time=01:00:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT/vendor/Voice-Privacy-Challenge-2024"

export N019_SKIP_DEPENDENCY_CHECK=1

echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "job=${SLURM_JOB_ID} scope=official_original_baseline"
echo "dependency_check=disabled_for_newer_scnet_binary_stack"
echo "HIP_VISIBLE_DEVICES=${HIP_VISIBLE_DEVICES:-unset}"
hy-smi || true

bash "$N019_OFFICIAL_ROOT/scripts/preflight_dcu_remote.sh"
python -u run_evaluation.py \
  --config "$N019_OFFICIAL_ROOT/configs/eval_original_test_only_pre.yaml" \
  --force_compute False
