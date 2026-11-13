#!/bin/bash
#SBATCH --job-name=n019_voc_hpc_long
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=16:00:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

export N019_OFFICIAL_ROOT="$HOME/voice_projects/code/n019_official_lr2e4_resume"
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

echo "user=$(id -un) host=$(hostname) date=$(date -Is) job=${SLURM_JOB_ID}"
echo "mode=HPC long dcu=1 total_batch=16 budget=15.5h"

export N019_NPROC=1
export N019_VOCODER_TOTAL_BATCH=16
export N019_VOCODER_WORKERS=4
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RUN_NAME="vocoder_nt_hpc_ft14k_long"
export N019_VOCODER_OUT="$N019_OFFICIAL_RUNS/vocoder_nt_hpc_ft14k_long_20261109"
export N019_VOCODER_STEPS=400000
export N019_VOCODER_MAX_HOURS=15.5
export N019_VOCODER_CHECKPOINT_INTERVAL=2000
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL=2000
export N019_VOCODER_KEEP_INTERVAL=50000
export N019_VOCODER_VALIDATION_INTERVAL=2000
export N019_VOCODER_VALIDATION_LIMIT=64
export N019_VOCODER_SELECTION_POLICY=mos_offline
export N019_VOCODER_EARLY_STOP_PATIENCE=0
export N019_VOCODER_LR=2e-4
export N019_VOCODER_GRAD_CLIP_NORM=0.0
export N019_VOCODER_INIT_GENERATOR="$N019_OFFICIAL_RUNS/vocoder_nt_2x_ft14k_lr2e4_20261109_061704/snapshots/generator_step00014000.pt"
export N019_VOCODER_INIT_GENERATOR_SHA256=479b982cecd4cbfc2628e089bea672ff67461e61a9f8956d49d4c426344f1dc6
export N019_SKIP_PATH_VERIFY=1
export N019_TRAINING_DATA_MARKER="$N019_OFFICIAL_LOGS/d6_training_data_ready.json"
export N019_TRAINING_EXPECTED_ROWS=33236
export N019_STAGE_TRACE=1

bash "$N019_OFFICIAL_ROOT/scripts/run_vocoder_ddp.sh"
