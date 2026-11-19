#!/bin/bash
#SBATCH --job-name=n019_l9ls360units
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

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

MANIFEST="${N019_LAYER9_LS360_MANIFEST:-$HOME/voice_projects/data/n019_official/processed/manifests/librispeech_train_clean_360_d10paths_20261117.jsonl}"
CODEBOOK="${N019_LAYER9_CODEBOOK:-$HOME/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100_layer9_aligned/kmeans_aligned_to_layer6.npz}"
HUBERT="${N019_LAYER9_HUBERT:-/public/home/a094f4d6/voice_projects/models/n019_official/hubert}"
OUT="${N019_LAYER9_LS360_OUT:-$HOME/voice_projects/data/n019_official/processed/units/librispeech_train_clean_360_layer9_aligned_20261117}"
EXPECTED_RECORDS=104014
EXPECTED_CODEBOOK_SHA=a0159483843f952e5ac9ac88cb410ca517d7d437c4ddcaf49535ef4be0284c2b

for required in "$MANIFEST" "$CODEBOOK"; do
  test -f "$required" || {
    echo "Missing layer-9 LS360 input: $required" >&2
    exit 1
  }
done
test -d "$HUBERT"
test "$(sha256sum "$CODEBOOK" | awk '{print $1}')" = "$EXPECTED_CODEBOOK_SHA"
mkdir -p "$OUT"

bash scripts/gpu_tiny_matmul_watchdog.sh

if [[ ! -s "$OUT/unit_records.jsonl" ]]; then
  RESUME_ARGS=()
  if [[ -e "$OUT/unit_records.partial.jsonl" ]]; then
    RESUME_ARGS=(--resume)
  fi
  python -u -m n019.units \
    --manifest "$MANIFEST" \
    --out "$OUT" \
    --hubert-model "$HUBERT" \
    --codebook "$CODEBOOK" \
    --layer 9 \
    --k 200 \
    --seed 20261102 \
    --batch-size 16 \
    --workers 4 \
    --device cuda \
    "${RESUME_ARGS[@]}"
fi

test "$(wc -l < "$OUT/unit_records.jsonl")" = "$EXPECTED_RECORDS"
python - "$OUT" "$EXPECTED_RECORDS" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
expected = int(sys.argv[2])
metadata = json.loads((out / "units_metadata.json").read_text())
checks = {
    "records": int(metadata["records"]),
    "kmeans_k": int(metadata["kmeans_k"]),
    "hubert_layer": int(metadata["hubert_layer"]),
    "codebook_sha256": metadata["codebook_sha256"],
}
if checks["records"] != expected:
    raise SystemExit(f"Unexpected row count: {checks['records']}")
if checks["kmeans_k"] != 200:
    raise SystemExit(f"Unexpected K: {checks['kmeans_k']}")
if checks["hubert_layer"] != 9:
    raise SystemExit(f"Unexpected HuBERT layer: {checks['hubert_layer']}")
expected_sha = "a0159483843f952e5ac9ac88cb410ca517d7d437c4ddcaf49535ef4be0284c2b"
if checks["codebook_sha256"] != expected_sha:
    raise SystemExit(f"Unexpected codebook hash: {checks['codebook_sha256']}")
print(json.dumps(checks, sort_keys=True))
PY

sha256sum \
  "$OUT/unit_records.jsonl" \
  "$OUT/units_metadata.json" \
  "$CODEBOOK"
echo "N019_LAYER9_LS360_UNITS_COMPLETE out=$OUT"
