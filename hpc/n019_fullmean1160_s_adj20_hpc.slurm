#!/usr/bin/env bash
#SBATCH --job-name=n019_fullmean_adj20_s
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=03:00:00
#SBATCH --exclude=f11r1n01,f11r2n13
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

RUN_ROOT="$N019_OFFICIAL_RUNS/privacy/fullmean1160_du_pred_nt_s_20261112"
export N019_OFFICIAL_ROOT="$ROOT"
export TMPDIR="/dev/shm/n019_s_adj20_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

export N019_DATA_SUFFIX="_n019_fullmean1160_20261112"
export N019_RUN_NAME="fullmean1160_du_pred_nt_s_adj20_lr1e3"
export N019_S_EVAL_OUT="$RUN_ROOT/s_eval_adj20_lr1e3"
export N019_ASV_CONFIG="$ROOT/configs/eval_paper_test_only_post_adj20.yaml"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "purpose=authors-prior adjusted E-VPC S diagnostic: lr=0.001 epochs=20"
echo "suffix=$N019_DATA_SUFFIX"
echo "out=$N019_S_EVAL_OUT"
echo "asv_config=$N019_ASV_CONFIG"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

exec bash "$ROOT/scripts/run_s_eval_remote.sh"
