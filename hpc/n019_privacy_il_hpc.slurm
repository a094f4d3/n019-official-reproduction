#!/usr/bin/env bash
#SBATCH --job-name=n019_privacy_il
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

: "${N019_DATA_SUFFIX:?Set N019_DATA_SUFFIX in the submit environment}"
: "${N019_VPC_DATA:?Set N019_VPC_DATA in the submit environment}"
export N019_DATA_SUFFIX
export N019_VPC_DATA
export N019_RUN_NAME="${N019_RUN_NAME:-du_pred_nt_privacy_il}"
export N019_PRIVACY_IL_OUT="${N019_PRIVACY_IL_OUT:-$N019_OFFICIAL_RUNS/eval_user/$N019_RUN_NAME}"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "suffix=$N019_DATA_SUFFIX"
echo "vpc_data=$N019_VPC_DATA"
echo "out=$N019_PRIVACY_IL_OUT"

bash "$ROOT/scripts/run_du_pred_nt_privacy_il_remote.sh"
