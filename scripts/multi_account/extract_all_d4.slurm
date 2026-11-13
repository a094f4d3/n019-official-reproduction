#!/bin/bash
#SBATCH --job-name=n019_extract_only
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=32G
#SBATCH --time=01:30:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

echo "user=$(id -un) host=$(hostname) job=${SLURM_JOB_ID} date=$(date -Is)"
echo "scope=extraction_and_integrity_checks_only"
echo "HIP_VISIBLE_DEVICES=${HIP_VISIBLE_DEVICES:-unset}"

bash "$HOME/voice_projects/code/n019_official/scripts/multi_account/extract_all_d4_remote.sh"
