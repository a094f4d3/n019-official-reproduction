#!/usr/bin/env bash
#SBATCH --job-name=n019_durstrong
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=01:00:00
#SBATCH --output=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_durstrong_%j.out

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_OFFICIAL_ROOT="$ROOT"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

export N019_DURATION_EMBEDDING_KIND=pred
export N019_DURATION_RUN_NAME=duration_pred_strong_20261117
export N019_DURATION_EPOCHS=60
export N019_DURATION_BATCH_SIZE=64
export N019_DURATION_WORKERS=8
export N019_DURATION_LR=0.0008
export N019_DURATION_RECORDS=/public/home/a094f4d4/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100/unit_records.jsonl

echo "job=${SLURM_JOB_ID} purpose=strong unconditional duration predictor"
echo "records=$N019_DURATION_RECORDS lr=$N019_DURATION_LR batch=$N019_DURATION_BATCH_SIZE epochs=$N019_DURATION_EPOCHS"
echo "hypothesis=the DISSC-derived optimizer scale may reduce average-rhythm underfitting and improve W-NT L without changing the vocoder"

bash "$ROOT/scripts/run_duration_ai.sh"

OUT="$N019_OFFICIAL_RUNS/$N019_DURATION_RUN_NAME"
test -s "$OUT/best.pt"
sha256sum "$OUT/best.pt" "$OUT/last.pt" "$OUT/meta.json"
echo "N019_DURATION_PRED_STRONG_COMPLETE out=$OUT"
