#!/bin/bash
#SBATCH --job-name=n019_hdiag
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=dcu:1
#SBATCH --mem=28G
#SBATCH --time=00:05:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

export AMD_SERIALIZE_KERNEL=1
export TORCH_SHOW_CPP_STACKTRACES=1

echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "job=${SLURM_JOB_ID} HIP_VISIBLE_DEVICES=${HIP_VISIBLE_DEVICES:-unset}"
hy-smi || true

python -u -m n019.diagnose_hubert \
  --hubert-model "$N019_OFFICIAL_MODELS/hubert" \
  --manifest "$N019_OFFICIAL_DATA/processed/manifests/libritts_train_clean_100.jsonl" \
  --out "$N019_OFFICIAL_RUNS/hubert_diag_${SLURM_JOB_ID}.json"
