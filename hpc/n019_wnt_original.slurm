#!/bin/bash
#SBATCH --job-name=n019_wnt_orig
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=dcu:1
#SBATCH --mem=24G
#SBATCH --time=00:30:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

export N019_DATA_SUFFIX=_n019
export N019_RUN_NAME=original_wnt_n019
export N019_WNT_ATTACKS=I

echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "job=${SLURM_JOB_ID} scope=original_wnt"

bash "$N019_OFFICIAL_ROOT/scripts/preflight_dcu_remote.sh"
bash "$N019_OFFICIAL_ROOT/scripts/evaluate_wnt_remote.sh"
