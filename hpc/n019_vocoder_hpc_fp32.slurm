#!/bin/bash
#SBATCH --job-name=n019_voc_fp32_hpc
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=40:00:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

export N019_OFFICIAL_ROOT="$HOME/voice_projects/code/n019_official"
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

echo "user=$(id -un) host=$(hostname) date=$(date -Is) job=${SLURM_JOB_ID}"
echo "mode=HPC FP32 dcu=1 total_batch=16 budget=39.5h"

export N019_NPROC=1
export N019_VOCODER_TOTAL_BATCH=16
export N019_VOCODER_WORKERS=4
export N019_VOCODER_TYPE=nt
export N019_VOCODER_BF16=0
export N019_VOCODER_RUN_NAME="vocoder_nt_hpc_hpclong6k_fp32"
export N019_VOCODER_OUT="$N019_OFFICIAL_RUNS/vocoder_nt_hpc_hpclong6k_fp32_20261109"
export N019_VOCODER_STEPS=400000
export N019_VOCODER_MAX_HOURS=39.5
export N019_VOCODER_CHECKPOINT_INTERVAL=2000
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL=2000
export N019_VOCODER_KEEP_INTERVAL=50000
export N019_VOCODER_VALIDATION_INTERVAL=2000
export N019_VOCODER_VALIDATION_LIMIT=64
export N019_VOCODER_SELECTION_POLICY=mos_offline
export N019_VOCODER_EARLY_STOP_PATIENCE=0
export N019_VOCODER_LR=2e-4
export N019_VOCODER_GRAD_CLIP_NORM=0.0
export N019_VOCODER_INIT_GENERATOR="$N019_OFFICIAL_DATA/checkpoints/n019_hpclong/generator_step00006000.pt"
export N019_VOCODER_INIT_GENERATOR_SHA256=4452ad40022ef509b7d6fda7a3786cc12eef6e29704bd51be2ccc5e4e1485040

# Reuse d6's already-finalized official LibriTTS train-clean-100 assets.
export N019_VOCODER_RECORDS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libritts_train_clean_100/unit_records.jsonl
export N019_VOCODER_EMBEDDINGS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz
export N019_SKIP_PATH_VERIFY=1
export N019_TRAINING_DATA_MARKER=/public/home/a094f4d6/voice_projects/logs/n019_official/d6_training_data_ready.json
export N019_TRAINING_EXPECTED_ROWS=33236
export N019_STAGE_TRACE=1

bash "$N019_OFFICIAL_ROOT/scripts/run_vocoder_ddp.sh"
