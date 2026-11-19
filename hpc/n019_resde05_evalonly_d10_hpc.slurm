#!/usr/bin/env bash
#SBATCH --job-name=n019_resde05_evalonly
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=00:30:00
#SBATCH --exclude=f11r1n01,f11r2n12,f11r2n13
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

export N019_OFFICIAL_ROOT="$ROOT"
export TMPDIR="/dev/shm/n019_resde05_eval_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

export N019_VPC_DATA="$N019_OFFICIAL_DATA/vpc/data"
export N019_DATA_SUFFIX="_n019_ntecres025_durextra0p5_20261118"
export N019_RUN_NAME="ntecres025_durextra0p5_evalonly_20261118"
export N019_S_EVAL_OUT="$N019_OFFICIAL_RUNS/privacy/ntecres025_durextra0p5_20261118_s/s_eval"
export N019_ASV_CONFIG="$ROOT/configs/eval_paper_test_only_post_reuse_ckpt.yaml"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "suffix=$N019_DATA_SUFFIX"
echo "out=$N019_S_EVAL_OUT"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

exec bash "$ROOT/scripts/run_s_eval_remote.sh"
