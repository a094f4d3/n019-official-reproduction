#!/usr/bin/env bash
#SBATCH --job-name=n019_sc075_missing
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=01:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "purpose=softcap075 E-VPC I/L and W-NT I"

exec bash "$ROOT/scripts/run_softcap075_missing_il_wnti_ai_20261119.sh"
