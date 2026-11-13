#!/bin/bash
#SBATCH --job-name=n019_dur_pred
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=dcu:1
#SBATCH --mem=30G
#SBATCH --time=00:45:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

OUT="$N019_OFFICIAL_RUNS/duration_pred_main"
RESUME_FLAG=""
if [[ -f "$OUT/last.pt" ]]; then
  RESUME_FLAG="--resume"
fi
echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "job=${SLURM_JOB_ID} scope=duration_pred out=$OUT resume=${RESUME_FLAG:-false}"

bash "$N019_OFFICIAL_ROOT/scripts/preflight_dcu_remote.sh"
python -u -m n019.duration \
  --records "$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_100/unit_records.jsonl" \
  --speaker-dim 0 \
  --embedding-kind none \
  --epochs 30 \
  --batch-size 32 \
  --workers 4 \
  --device cuda \
  --out "$OUT" \
  ${RESUME_FLAG}
