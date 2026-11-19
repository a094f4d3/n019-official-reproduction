#!/bin/bash
#SBATCH --job-name=n019_layer9_voc
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=08:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

RECORDS="${N019_LAYER9_ALIGNED_RECORDS:-$HOME/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100_layer9_aligned/unit_records.jsonl}"
EMBEDDINGS="${N019_LAYER9_EMBEDDINGS:-/public/home/a094f4d6/voice_projects/data/n019_official/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz}"
INIT_GENERATOR="${N019_LAYER9_INIT_GENERATOR:-/public/home/a094f4d6/voice_projects/tmp/n019_privacy_fix_20261111/generator_soup2.pt}"
INIT_SHA256="${N019_LAYER9_INIT_SHA256:-ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6}"
OUT="${N019_LAYER9_VOCODER_OUT:-$HOME/voice_projects/runs/n019_official/vocoder_nt_layer9_aligned_pilot_20261116}"

test -s "$RECORDS"
test -s "$EMBEDDINGS"
test -s "$INIT_GENERATOR"
test "$(sha256sum "$INIT_GENERATOR" | awk '{print $1}')" = "$INIT_SHA256"

export N019_VOICE_ROOT="$HOME/voice_projects"
export N019_SHARED_VOICE_ROOT=/public/home/a094f4d6/voice_projects
export N019_VOCODER_RECORDS="$RECORDS"
export N019_VOCODER_EMBEDDINGS="$EMBEDDINGS"
export N019_VOCODER_OUT="$OUT"
export N019_VOCODER_INIT_GENERATOR="$INIT_GENERATOR"
export N019_VOCODER_INIT_GENERATOR_SHA256="$INIT_SHA256"
export N019_VOCODER_STEPS="${N019_LAYER9_STEPS:-20000}"
export N019_VOCODER_MAX_HOURS="${N019_LAYER9_MAX_HOURS:-7}"
export N019_VOCODER_LR="${N019_LAYER9_LR:-1e-4}"
export N019_VOCODER_TOTAL_BATCH="${N019_LAYER9_BATCH:-16}"
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL=2000
export N019_VOCODER_CHECKPOINT_INTERVAL=2000
export N019_VOCODER_VALIDATION_INTERVAL=2000
export N019_VOCODER_KEEP_INTERVAL=20000
export N019_VOCODER_SELECTION_POLICY=mel_l1
export N019_VOCODER_EARLY_STOP_MIN_STEPS=20000
export N019_VOCODER_EARLY_STOP_PATIENCE=20
export N019_VOCODER_BF16=1
export N019_VOCODER_OPTIMIZER=adamw
export N019_NPROC=1

bash scripts/gpu_tiny_matmul_watchdog.sh
bash scripts/run_vocoder_ddp.sh

sha256sum "$OUT"/snapshots/generator_step*.pt "$OUT/last.pt"
echo "N019_LAYER9_VOCODER_PILOT_COMPLETE out=$OUT"
