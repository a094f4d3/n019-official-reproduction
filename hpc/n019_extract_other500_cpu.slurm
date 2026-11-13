#!/usr/bin/env bash
#SBATCH --job-name=n019_extract_other500
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=dcu:1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/n019_extract_other500_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/n019_extract_other500_%j.err

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

echo "job=${SLURM_JOB_ID} host=$(hostname) date=$(date -Is)"
echo "scope=LibriTTS train-other-500 CPU extraction"
df -h "$N019_VOICE_ROOT"

bash "$ROOT/scripts/ssh_extract_other500_remote.sh"
