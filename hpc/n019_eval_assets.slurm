#!/bin/bash
#SBATCH --job-name=n019_eval_data
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=32G
#SBATCH --time=01:00:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "job=${SLURM_JOB_ID} scope=evaluation_assets"

bash "$N019_OFFICIAL_ROOT/scripts/preflight_dcu_remote.sh"
bash "$N019_OFFICIAL_ROOT/scripts/prepare_eval_assets_remote.sh"
