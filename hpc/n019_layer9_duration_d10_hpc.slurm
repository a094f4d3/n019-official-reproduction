#!/bin/bash
#SBATCH --job-name=n019_layer9_dur
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=04:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

RECORDS="${N019_LAYER9_DURATION_RECORDS:-$HOME/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100_layer9_aligned/unit_records.jsonl}"
OUT="${N019_LAYER9_DURATION_OUT:-$HOME/voice_projects/runs/n019_official/duration_pred_layer9_aligned_20261116}"

test -s "$RECORDS"
test "$(wc -l < "$RECORDS")" = 33236
test ! -e "$OUT/last.pt"
mkdir -p "$OUT"

bash scripts/gpu_tiny_matmul_watchdog.sh

python -u -m n019.duration \
  --records "$RECORDS" \
  --speaker-dim 0 \
  --embedding-kind none \
  --epochs 30 \
  --batch-size 32 \
  --lr 3e-4 \
  --workers 4 \
  --device cuda \
  --out "$OUT"

test -s "$OUT/best.pt"
test -s "$OUT/last.pt"
test -s "$OUT/meta.json"
sha256sum "$OUT/best.pt" "$OUT/last.pt" "$OUT/meta.json" "$OUT/history.json"
echo "N019_LAYER9_DURATION_COMPLETE out=$OUT"
