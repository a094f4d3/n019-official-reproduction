#!/bin/bash
#SBATCH --job-name=n019_wntl_ckpt_screen
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

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
export N019_WNT_SCREEN_OUT="${N019_WNT_SCREEN_OUT:-$HOME/voice_projects/runs/n019_official/privacy/wntl_snapshot_screen_20261111}"
export N019_WNT_SCREEN_SNAPSHOT_ROOT="${N019_WNT_SCREEN_SNAPSHOT_ROOT:-$HOME/voice_projects/runs/n019_official/vocoder_nt_hpc_ft14k_long_20261109/snapshots}"

bash "$ROOT/scripts/run_checkpoint_wnt_l_screen_remote.sh"
