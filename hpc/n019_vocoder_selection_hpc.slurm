#!/bin/bash
#SBATCH --job-name=n019_vocsel_hpc
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=04:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err
#SBATCH --export=ALL

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-/public/home/$(id -un)/voice_projects/code/n019_official}"
export N019_OFFICIAL_ROOT="$ROOT"

source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "slurm_job_id=${SLURM_JOB_ID:-unset} partition=${SLURM_JOB_PARTITION:-unset}"
echo "cuda_visible_devices=${CUDA_VISIBLE_DEVICES:-unset} hip_visible_devices=${HIP_VISIBLE_DEVICES:-unset}"
echo "selection_out=${N019_SELECTION_OUT:-unset}"
echo "snapshot_dir=${N019_SELECTION_SNAPSHOT_DIR:-unset}"
hy-smi || true

bash "$ROOT/scripts/run_vocoder_snapshot_selection_ai.sh"
