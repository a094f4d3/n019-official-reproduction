#!/usr/bin/env bash
#SBATCH --job-name=n019_wnt_s
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=12:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"

export N019_DATA_SUFFIX="${N019_DATA_SUFFIX:?Set N019_DATA_SUFFIX}"
export N019_WNT_S_RUN_NAME="${N019_WNT_S_RUN_NAME:-wnt_s_soup2_w40_shrink01}"
export N019_WNT_S_OUT="${N019_WNT_S_OUT:-$N019_OFFICIAL_RUNS/privacy/$N019_WNT_S_RUN_NAME}"
export N019_NPROC=1
export N019_WNT_S_TOTAL_BATCH="${N019_WNT_S_TOTAL_BATCH:-16}"
export N019_WNT_S_WORKERS="${N019_WNT_S_WORKERS:-4}"
export N019_WNT_S_EPOCHS="${N019_WNT_S_EPOCHS:-20}"
export N019_WNT_S_MAX_HOURS="${N019_WNT_S_MAX_HOURS:-10}"
export N019_WNT_S_LR="${N019_WNT_S_LR:-1e-3}"
export N019_WNT_S_HEAD_LR="${N019_WNT_S_HEAD_LR:-1e-3}"
export N019_WNT_S_FREEZE_WAVLM="${N019_WNT_S_FREEZE_WAVLM:-1}"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "suffix=$N019_DATA_SUFFIX"
echo "out=$N019_WNT_S_OUT"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

bash "$ROOT/scripts/train_wnt_s_remote.sh"
