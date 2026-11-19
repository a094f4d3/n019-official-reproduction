#!/usr/bin/env bash
#SBATCH --job-name=n019_cap15_s
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=04:00:00
#SBATCH --output=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_cap15_s_%j.out
#SBATCH --error=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_cap15_s_%j.err

set -euo pipefail
exec bash /public/home/a094f4d10/voice_projects/code/n019_official/scripts/n019_res05_dur05_cap15_s_shm.sh
