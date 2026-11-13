#!/bin/bash
#SBATCH --job-name=n019_voc_ddp_pilot
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --gres=dcu:2
#SBATCH --mem=40G
#SBATCH --time=00:15:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

export N019_NPROC=2
export N019_VOCODER_STEPS=1000
export N019_VOCODER_TOTAL_BATCH=32
export N019_VOCODER_MAX_HOURS=0.20
export N019_VOCODER_CHECKPOINT_INTERVAL=500
export N019_VOCODER_KEEP_INTERVAL=1000
export N019_VOCODER_VALIDATION_INTERVAL=500
export N019_VOCODER_WORKERS=4
export N019_VOCODER_RUN_NAME="vocoder_nt_ddp_pilot_${SLURM_JOB_ID}"

echo "job=${SLURM_JOB_ID} mode=HPC dcu=2 wall_limit=00:15:00"
echo "effective_batch=32 batch_per_rank=16 steps=1000 bf16=true"
bash "$N019_OFFICIAL_ROOT/scripts/run_vocoder_ddp.sh"
