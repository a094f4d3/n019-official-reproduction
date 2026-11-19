#!/bin/bash
#SBATCH --job-name=n019_layer9_align
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=dcu:1
#SBATCH --mem=24G
#SBATCH --time=00:30:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

REFERENCE_RECORDS="${N019_LAYER9_REFERENCE_RECORDS:-/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libritts_train_clean_100/unit_records.jsonl}"
TARGET_RECORDS="${N019_LAYER9_TARGET_RECORDS:-$HOME/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100_layer9/unit_records.jsonl}"
REFERENCE_CODEBOOK="${N019_LAYER9_REFERENCE_CODEBOOK:-/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100/kmeans_k200_seed20261102.npz}"
TARGET_CODEBOOK="${N019_LAYER9_TARGET_CODEBOOK:-$HOME/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100_layer9/kmeans_k200_seed20261102.npz}"
OUT="${N019_LAYER9_ALIGNED_OUT:-$HOME/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100_layer9_aligned}"

test -s "$REFERENCE_RECORDS"
test -s "$TARGET_RECORDS"
test -s "$REFERENCE_CODEBOOK"
test -s "$TARGET_CODEBOOK"

bash scripts/gpu_tiny_matmul_watchdog.sh
mkdir -p "$OUT"

python -u scripts/align_layer_units.py \
  --reference-records "$REFERENCE_RECORDS" \
  --target-records "$TARGET_RECORDS" \
  --reference-codebook "$REFERENCE_CODEBOOK" \
  --target-codebook "$TARGET_CODEBOOK" \
  --out "$OUT" \
  --k 200

test "$(wc -l < "$OUT/unit_records.jsonl")" = 33236
python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

import numpy as np

out = Path(sys.argv[1])
mapping = np.load(out / "alignment.npz")["target_to_reference"]
if mapping.shape != (200,) or len(set(mapping.tolist())) != 200:
    raise SystemExit("Alignment mapping is not a 200-way bijection")
rows = [
    json.loads(line)
    for line in (out / "unit_records.jsonl").read_text().splitlines()
    if line.strip()
]
if len(rows) != 33236:
    raise SystemExit(f"Unexpected rows: {len(rows)}")
print(f"rows={len(rows)} mapping_values={len(set(mapping.tolist()))}")
PY

sha256sum \
  "$OUT/unit_records.jsonl" \
  "$OUT/kmeans_aligned_to_layer6.npz" \
  "$OUT/alignment.npz" \
  "$OUT/alignment.json"
echo "N019_LAYER9_ALIGN_COMPLETE out=$OUT"
