#!/bin/bash
#SBATCH --job-name=n019_fullmean1160_prep
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

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

BASE843="$N019_OFFICIAL_DATA/processed/embeddings/target_speaker_full168023_mean843_20261110/nt_speaker_embeddings.npz"
MISSING315="$N019_OFFICIAL_DATA/processed/embeddings/target_speaker_fullmean315_hpc_20261112/nt_speaker_embeddings.npz"
MISSING2_MANIFEST="$N019_OFFICIAL_RUNS/target_fullmean_audit_2spk_20261112/missing_speakers.jsonl"
OUT_ROOT="$N019_OFFICIAL_DATA/processed/embeddings/target_speaker_fullmean1160_20261112"
MISSING2_OUT="$OUT_ROOT/missing2"
FULL_OUT="$OUT_ROOT/nt_speaker_embeddings.npz"
TEST_MAP="$N019_OFFICIAL_DATA/processed/targets/full_other500_1160_seed20261102/libri_test_target_map.jsonl"
LS360_MAP="$N019_OFFICIAL_DATA/processed/targets/full_other500_1160_seed20261102/librispeech_train_clean_360_target_map.jsonl"

for required in "$BASE843" "$MISSING315" "$MISSING2_MANIFEST" "$TEST_MAP" "$LS360_MAP"; do
  test -f "$required" || {
    echo "Missing fullmean prep input: $required" >&2
    exit 1
  }
done
test "$(wc -l < "$MISSING2_MANIFEST")" = 6
test "$(wc -l < "$TEST_MAP")" = 1934
test "$(wc -l < "$LS360_MAP")" = 104014

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "base843=$BASE843"
echo "missing315=$MISSING315"
echo "missing2_manifest=$MISSING2_MANIFEST"
echo "out=$FULL_OUT"
hy-smi || true

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

mkdir -p "$OUT_ROOT"
python -u -m n019.extract_speakers \
  --manifest "$MISSING2_MANIFEST" \
  --model "$N019_OFFICIAL_MODELS/wpro" \
  --kind nt \
  --level speaker \
  --checkpoint-every 10 \
  --device cuda \
  --out "$MISSING2_OUT"

python "$ROOT/scripts/merge_target_speaker_means.py" \
  --base-embeddings "$BASE843" \
  --additional-embeddings "$MISSING315" \
  --additional-embeddings "$MISSING2_OUT/nt_speaker_embeddings.npz" \
  --out "$FULL_OUT" \
  --shrink 0 \
  --metadata "$OUT_ROOT/metadata.json" \
  --expected-keys 1160

python "$ROOT/scripts/subset_target_embeddings.py" \
  --target-map "$TEST_MAP" \
  --embeddings "$FULL_OUT" \
  --key target_speaker \
  --dimension 250 \
  --out "$OUT_ROOT/test_941.npz" \
  --summary "$OUT_ROOT/test_941.meta.json"

python - "$FULL_OUT" "$TEST_MAP" "$LS360_MAP" \
  "$OUT_ROOT/test_941.npz" <<'PY'
import json
import sys
from pathlib import Path

import numpy as np

full_path, test_map_path, ls360_map_path, test_subset_path = map(
    Path, sys.argv[1:]
)

def required_keys(path):
    return {
        str(json.loads(line)["target_speaker"])
        for line in path.open(encoding="utf-8")
        if line.strip()
    }

full = np.load(full_path, allow_pickle=False)
test_subset = np.load(test_subset_path, allow_pickle=False)
try:
    if len(full.files) != 1160:
        raise SystemExit(f"Expected 1160 full keys, got {len(full.files)}")
    if set(test_subset.files) != required_keys(test_map_path):
        raise SystemExit("Test subset/public target-map key mismatch")
    ls360_keys = required_keys(ls360_map_path)
    if len(ls360_keys) != 1160:
        raise SystemExit(f"Expected 1160 LS360 speakers, got {len(ls360_keys)}")
    missing_ls360 = ls360_keys - set(full.files)
    if missing_ls360:
        raise SystemExit(
            f"LS360 target map missing {len(missing_ls360)} full keys"
        )
    for archive, label in ((full, "full"), (test_subset, "test_subset")):
        for key in archive.files:
            value = archive[key]
            if value.shape != (250,):
                raise SystemExit(f"{label}:{key} shape {value.shape}")
            if not np.isfinite(value).all():
                raise SystemExit(f"{label}:{key} is non-finite")
            norm = float(np.linalg.norm(value))
            if abs(norm - 1.0) > 1e-4:
                raise SystemExit(f"{label}:{key} norm {norm}")
    test_key_count = len(test_subset.files)
finally:
    full.close()
    test_subset.close()

print(
    "FULLMEAN1160_READY "
    f"full_keys=1160 test_keys={test_key_count} "
    "ls360_speakers=1160"
)
PY

sha256sum \
  "$MISSING2_MANIFEST" \
  "$FULL_OUT" \
  "$OUT_ROOT/metadata.json" \
  "$TEST_MAP" \
  "$LS360_MAP" \
  "$OUT_ROOT/test_941.npz" \
  "$OUT_ROOT/test_941.meta.json"
echo "FULLMEAN1160_PREP_COMPLETE out=$OUT_ROOT"
