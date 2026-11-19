#!/usr/bin/env bash
#SBATCH --job-name=n019_softcap075_eval
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=01:30:00
#SBATCH --output=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_softcap075_eval_%j.out
#SBATCH --error=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_softcap075_eval_%j.err

set -euo pipefail
exec bash /public/home/a094f4d10/voice_projects/code/n019_official/scripts/run_softcap075_full_eval_hpc.sh
