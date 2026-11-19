#!/bin/bash
#SBATCH --job-name=n019_dunntutt
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=01:30:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="/public/home/a094f4d10/voice_projects/code/n019_official"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="/public/home/a094f4d10/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
export TMPDIR="/dev/shm/n019_dunntutt_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname)"
echo "purpose=DU-nt-nt target-utterance full quality evaluation"
echo "resources=1 DCU,16 CPU,60 GB,1.5 h"

bash scripts/run_du_nt_nt_utt_full_eval_ai.sh
