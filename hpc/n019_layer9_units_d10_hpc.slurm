#!/bin/bash
#SBATCH --job-name=n019_layer9_units
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=08:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

MANIFEST="${N019_LAYER9_MANIFEST:-/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libritts_train_clean_100/unit_records.jsonl}"
HUBERT="${N019_LAYER9_HUBERT:-/public/home/a094f4d6/voice_projects/models/n019_official/hubert}"
OUT="${N019_LAYER9_UNITS_OUT:-$HOME/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100_layer9}"

test -s "$MANIFEST"
test -d "$HUBERT"
mkdir -p "$OUT"

bash scripts/gpu_tiny_matmul_watchdog.sh

if [[ ! -s "$OUT/unit_records.jsonl" ]]; then
  python -u -m n019.units \
    --manifest "$MANIFEST" \
    --out "$OUT" \
    --hubert-model "$HUBERT" \
    --layer 9 \
    --k 200 \
    --seed 20261102 \
    --batch-size 16 \
    --workers 4 \
    --device cuda
fi

test "$(wc -l < "$OUT/unit_records.jsonl")" = 33236
python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
metadata = json.loads((out / "units_metadata.json").read_text())
codebook = metadata["codebook"]
if int(metadata["records"]) != 33236:
    raise SystemExit(f"Unexpected row count: {metadata['records']}")
if int(metadata["kmeans_k"]) != 200:
    raise SystemExit(f"Unexpected K: {metadata['kmeans_k']}")
if int(metadata["hubert_layer"]) != 9:
    raise SystemExit(f"Unexpected HuBERT layer: {metadata['hubert_layer']}")
print(f"codebook={codebook}")
print(
    f"rows={metadata['records']} layer={metadata['hubert_layer']} "
    f"k={metadata['kmeans_k']}"
)
PY

sha256sum "$OUT/unit_records.jsonl" "$OUT/units_metadata.json" "$OUT"/*.npz
echo "N019_LAYER9_UNITS_COMPLETE out=$OUT"
