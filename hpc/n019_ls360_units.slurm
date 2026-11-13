#!/bin/bash
#SBATCH --job-name=n019_ls360_units
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=40G
#SBATCH --time=06:00:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"
export N019_UNIT_BATCH_SIZE=8
export N019_UNIT_WORKERS=4

bash "$N019_OFFICIAL_ROOT/scripts/preflight_dcu_remote.sh"
bash "$N019_OFFICIAL_ROOT/scripts/extract_ls360_units_remote.sh"
