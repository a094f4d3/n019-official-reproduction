#!/usr/bin/env bash
#SBATCH --job-name=n019_s_eval
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=08:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"

export N019_DATA_SUFFIX="${N019_DATA_SUFFIX:?Set N019_DATA_SUFFIX}"
export N019_RUN_NAME="${N019_RUN_NAME:-du_pred_nt_soup2_w40_shrink01_s_eval}"
export N019_S_EVAL_OUT="${N019_S_EVAL_OUT:-$N019_OFFICIAL_RUNS/privacy/$N019_RUN_NAME/s_eval}"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "suffix=$N019_DATA_SUFFIX"
echo "out=$N019_S_EVAL_OUT"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

bash "$ROOT/scripts/run_s_eval_remote.sh"
