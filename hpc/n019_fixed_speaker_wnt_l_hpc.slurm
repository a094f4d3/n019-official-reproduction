#!/bin/bash
#SBATCH --job-name=n019_fixedspk_wntl
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=00:45:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
export N019_OFFICIAL_ROOT="$ROOT"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

echo "user=$(id -un) host=$(hostname) date=$(date -Is) job=${SLURM_JOB_ID}"
echo "run_root=${N019_FIXED_RUN_ROOT:?Set N019_FIXED_RUN_ROOT}"

bash -x "$ROOT/scripts/run_fixed_speaker_wnt_l_remote.sh"
