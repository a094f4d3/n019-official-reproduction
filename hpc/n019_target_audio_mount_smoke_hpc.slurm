#!/bin/bash
#SBATCH --job-name=n019_tspk_mount
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=dcu:1
#SBATCH --mem=14G
#SBATCH --time=00:10:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

export N019_TARGET_SMOKE_MANIFEST="$N019_OFFICIAL_DATA/processed/targets/target_speaker_mean32_combined.jsonl"
bash "$ROOT/scripts/target_audio_mount_smoke_ai.sh"
