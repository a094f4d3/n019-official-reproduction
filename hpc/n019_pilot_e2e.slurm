#!/bin/bash
#SBATCH --job-name=n019_pilot_e2e
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --gres=dcu:1
#SBATCH --mem=40G
#SBATCH --time=00:25:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

export N019_DATA_SUFFIX=_n019_pilot
export N019_RUN_NAME=pilot_e2e
export N019_VOCODER="$N019_OFFICIAL_RUNS/vocoder_nt_pilot_1020953/last.pt"
export N019_DURATION_MODEL="$N019_OFFICIAL_RUNS/duration_pred_main/best.pt"

bash "$N019_OFFICIAL_ROOT/scripts/preflight_dcu_remote.sh"
bash "$N019_OFFICIAL_ROOT/scripts/run_pilot_e2e_remote.sh"
