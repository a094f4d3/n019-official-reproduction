#!/bin/bash
#SBATCH --job-name=n019_voc_hpc_pilot
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=00:20:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

export N019_OFFICIAL_ROOT="$HOME/voice_projects/code/n019_official_lr2e4_resume"
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

echo "user=$(id -un) host=$(hostname) date=$(date -Is) job=${SLURM_JOB_ID}"
echo "mode=HPC pilot dcu=1 total_batch=16"

export N019_NPROC=1
export N019_VOCODER_TOTAL_BATCH=16
export N019_VOCODER_WORKERS=3
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RUN_NAME="vocoder_nt_hpc_pilot_${SLURM_JOB_ID}"
export N019_VOCODER_OUT="$N019_OFFICIAL_RUNS/vocoder_nt_hpc_pilot_${SLURM_JOB_ID}"
export N019_VOCODER_STEPS=400
export N019_VOCODER_MAX_HOURS=0.2
export N019_VOCODER_CHECKPOINT_INTERVAL=200
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL=200
export N019_VOCODER_KEEP_INTERVAL=1000
export N019_VOCODER_VALIDATION_INTERVAL=200
export N019_VOCODER_VALIDATION_LIMIT=2
export N019_VOCODER_SELECTION_POLICY=mos_offline
export N019_VOCODER_EARLY_STOP_PATIENCE=0
export N019_VOCODER_LR=2e-4
export N019_VOCODER_GRAD_CLIP_NORM=0.0
export N019_VOCODER_INIT_GENERATOR="$N019_VOICE_ROOT/tmp/n019_2x14k_base.pt"
export N019_VOCODER_INIT_GENERATOR_SHA256=343b3a4117b69c72c3b1a2c4fbe69e6c10830af0caccc950e988af9f1828cf45
export N019_SKIP_PATH_VERIFY=1
export N019_TRAINING_DATA_MARKER="$N019_OFFICIAL_LOGS/d6_training_data_ready.json"
export N019_TRAINING_EXPECTED_ROWS=33236
export N019_STAGE_TRACE=1

bash "$N019_OFFICIAL_ROOT/scripts/run_vocoder_ddp.sh"
