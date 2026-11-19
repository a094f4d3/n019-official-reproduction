#!/usr/bin/env bash
#SBATCH -J n019_resmid_cap15_grid
#SBATCH -p hx1hdnormal
#SBATCH --gres=dcu:1
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 16
#SBATCH --mem=60G
#SBATCH -t 01:30:00
#SBATCH --exclude=f11r1n01,f11r2n13
#SBATCH -o /public/home/a094f4d10/voice_projects/logs/n019_official/n019_resmid_cap15_grid_%j.out
#SBATCH -e /public/home/a094f4d10/voice_projects/logs/n019_official/n019_resmid_cap15_grid_%j.err

set -euo pipefail
bash /public/home/a094f4d10/voice_projects/code/n019_official/scripts/n019_resmid_cap15_grid_shm.sh
