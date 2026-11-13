#!/usr/bin/env bash
#SBATCH --job-name=n019_wnt_s_eval
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=01:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"

export N019_DATA_SUFFIX="${N019_DATA_SUFFIX:?Set N019_DATA_SUFFIX}"
export N019_VPC_DATA="${N019_VPC_DATA:?Set N019_VPC_DATA}"
export N019_WNT_S_MODEL="${N019_WNT_S_MODEL:?Set N019_WNT_S_MODEL}"
export N019_WNT_ATTACKS=S
export N019_WNT_OUT="${N019_WNT_OUT:?Set N019_WNT_OUT}"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "suffix=$N019_DATA_SUFFIX"
echo "model=$N019_WNT_S_MODEL"
echo "out=$N019_WNT_OUT"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

bash "$ROOT/scripts/evaluate_wnt_remote.sh"
