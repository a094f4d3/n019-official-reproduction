#!/bin/bash
#SBATCH --job-name=n019_unit_leak
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=00:45:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

MANIFEST="${N019_LEAK_MANIFEST:-/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libritts_train_clean_100/unit_records.jsonl}"
HUBERT="${N019_LEAK_HUBERT:-/public/home/a094f4d6/voice_projects/models/n019_official/hubert}"
OUT="${N019_LEAK_OUT:-$N019_OFFICIAL_RUNS/unit_speaker_leakage_${SLURM_JOB_ID}}"

bash scripts/gpu_tiny_matmul_watchdog.sh
mkdir -p "$OUT"

python scripts/analyze_unit_speaker_leakage.py \
  --manifest "$MANIFEST" \
  --hubert-model "$HUBERT" \
  --layers 6,9 \
  --speakers 80 \
  --utterances-per-speaker 8 \
  --train-per-speaker 5 \
  --k 200 \
  --out "$OUT/unit_speaker_leakage.json"
