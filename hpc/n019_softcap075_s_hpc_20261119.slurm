#!/usr/bin/env bash
#SBATCH --job-name=n019_sc075_s
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=03:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"

export N019_SOFT_CAP_FRAMES=0.75
export N019_S_SUFFIX=_n019_softcap075_recovery_20261119
export N019_S_RUN_NAME=n019_softcap075_20261119
export N019_S_PUBLIC_OUT="$N019_OFFICIAL_RUNS/privacy/softcap075_full_s_hpc_20261119"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "purpose=softcap075 matching E-VPC S"
echo "resources=1 DCU 16 CPU 60GB wall=3h expected=2.5 worst=3.0 card-hours"

exec bash "$ROOT/scripts/n019_res05_dur05_cap15_s_shm.sh"
