#!/bin/bash
#SBATCH --job-name=n019_wnt_existing
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
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

: "${N019_DATA_SUFFIX:?Set N019_DATA_SUFFIX}"
: "${N019_VPC_DATA:?Set N019_VPC_DATA}"
: "${N019_WNT_OUT:?Set N019_WNT_OUT}"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

N019_DATA_SUFFIX="$N019_DATA_SUFFIX" \
N019_VPC_DATA="$N019_VPC_DATA" \
N019_WNT_BASE_VPC_DATA="$N019_VPC_DATA" \
N019_WNT_ATTACKS="${N019_WNT_ATTACKS:-L}" \
N019_WNT_OUT="$N019_WNT_OUT" \
  bash "$ROOT/scripts/evaluate_wnt_remote.sh"

sha256sum "$N019_WNT_OUT/summary.json"
echo "N019_WNT_EXISTING_COMPLETE suffix=$N019_DATA_SUFFIX out=$N019_WNT_OUT"
