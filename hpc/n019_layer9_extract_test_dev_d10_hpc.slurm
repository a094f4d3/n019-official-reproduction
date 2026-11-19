#!/bin/bash
#SBATCH --job-name=n019_layer9_evalunits
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=02:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

CODEBOOK="${N019_LAYER9_ALIGNED_CODEBOOK:-$HOME/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100_layer9_aligned/kmeans_aligned_to_layer6.npz}"
TEST_RECORDS="${N019_LAYER9_TEST_RECORDS:-/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libri_test_paperfix/unit_records.jsonl}"
DEV_RECORDS="${N019_LAYER9_DEV_RECORDS:-/public/home/a094f4d7/voice_projects/data/n019_official/processed/selection_dev100_vpc_units_20261108_retry1/units/unit_records.jsonl}"
HUBERT="${N019_LAYER9_HUBERT:-/public/home/a094f4d6/voice_projects/models/n019_official/hubert}"
OUT_ROOT="${N019_LAYER9_EVAL_UNITS_OUT:-$HOME/voice_projects/data/n019_official/processed/units/layer9_eval_20261116}"

test -s "$CODEBOOK"
test -s "$TEST_RECORDS"
test -s "$DEV_RECORDS"
test -d "$HUBERT"
mkdir -p "$OUT_ROOT/test" "$OUT_ROOT/dev100"

bash scripts/gpu_tiny_matmul_watchdog.sh

if [[ ! -s "$OUT_ROOT/test/unit_records.jsonl" ]]; then
  python -u -m n019.units \
    --manifest "$TEST_RECORDS" \
    --out "$OUT_ROOT/test" \
    --hubert-model "$HUBERT" \
    --codebook "$CODEBOOK" \
    --layer 9 \
    --k 200 \
    --seed 20261102 \
    --batch-size 16 \
    --workers 4 \
    --device cuda
fi

if [[ ! -s "$OUT_ROOT/dev100/unit_records.jsonl" ]]; then
  DEV_RESUME_ARGS=()
  if [[ -s "$OUT_ROOT/dev100/unit_records.partial.jsonl" ]]; then
    DEV_RESUME_ARGS=(--resume)
  fi
  python -u -m n019.units \
    --manifest "$DEV_RECORDS" \
    --out "$OUT_ROOT/dev100" \
    --hubert-model "$HUBERT" \
    --codebook "$CODEBOOK" \
    --layer 9 \
    --k 200 \
    --seed 20261102 \
    --batch-size 16 \
    --workers 4 \
    --device cuda \
    "${DEV_RESUME_ARGS[@]}"
fi

test "$(wc -l < "$OUT_ROOT/test/unit_records.jsonl")" = 1934
test "$(wc -l < "$OUT_ROOT/dev100/unit_records.jsonl")" = 100
sha256sum \
  "$OUT_ROOT/test/unit_records.jsonl" \
  "$OUT_ROOT/dev100/unit_records.jsonl" \
  "$OUT_ROOT/test/units_metadata.json" \
  "$OUT_ROOT/dev100/units_metadata.json"
echo "N019_LAYER9_EVAL_UNITS_COMPLETE out=$OUT_ROOT"
