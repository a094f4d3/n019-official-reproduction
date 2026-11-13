#!/bin/bash
#SBATCH --job-name=n019_wntl_seed_screen
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=00:40:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
export N019_SEED_SCREEN_OUT="${N019_SEED_SCREEN_OUT:-$HOME/voice_projects/runs/n019_official/privacy/wntl_seed_screen_20261111}"
export N019_SEED_SCREEN_TARGET_MAP_DIR="${N019_SEED_SCREEN_TARGET_MAP_DIR:-$HOME/voice_projects/runs/n019_official/target_sampling_diag_20261111}"
export N019_SEED_SCREEN_EMBEDDINGS="${N019_SEED_SCREEN_EMBEDDINGS:-$HOME/voice_projects/tmp/n019_target_shrink_ab_20261111/nt_speaker_embeddings_shrink005.npz}"
export N019_SEED_SCREEN_EMBEDDINGS_SHA="${N019_SEED_SCREEN_EMBEDDINGS_SHA:-2a6b340fb324b757cba15fbe8f2c3366752b372010b5bc3db9d61d5c19bada1e}"

bash "$ROOT/scripts/run_target_seed_wnt_l_screen_remote.sh"
