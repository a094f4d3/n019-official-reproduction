#!/usr/bin/env bash
#SBATCH --job-name=n019_res05de05_wnt_s
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=02:00:00
#SBATCH --exclude=f11r1n01,f11r1n07,f11r1n20,f11r2n12,f11r2n13
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
mkdir -p "$N019_OFFICIAL_LOGS"

export TMPDIR="/dev/shm/n019_res05_wnts_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"
export PYTHONFAULTHANDLER=1

export N019_DATA_SUFFIX=_n019_ntecres0p5_durextra0p5_20261118
export N019_WNT_S_RUN_NAME=ntecres0p5_durextra0p5_wnt_s_20261118
export N019_WNT_S_OUT="$N019_OFFICIAL_RUNS/privacy/$N019_WNT_S_RUN_NAME"
export N019_WNT_BASE_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_NPROC=1
export N019_WNT_S_TOTAL_BATCH=16
export N019_WNT_S_WORKERS=0
export N019_WNT_S_EPOCHS="${N019_WNT_S_EPOCHS:-10}"
export N019_WNT_S_MAX_HOURS="${N019_WNT_S_MAX_HOURS:-1.8}"
export N019_WNT_S_LR=1e-3
export N019_WNT_S_HEAD_LR=1e-3
export N019_WNT_S_FREEZE_WAVLM=1
export N019_WNT_S_RESET_SCHEDULER="${N019_WNT_S_RESET_SCHEDULER:-1}"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "suffix=$N019_DATA_SUFFIX"
echo "out=$N019_WNT_S_OUT"
echo "epochs=$N019_WNT_S_EPOCHS max_hours=$N019_WNT_S_MAX_HOURS"
echo "wall=2h expected=1.2 worst=2.0 card-hours"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

exec bash "$ROOT/scripts/train_wnt_s_remote.sh"
