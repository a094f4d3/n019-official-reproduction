#!/bin/bash
#SBATCH --job-name=n019_du_ecapa_nt_r2
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

ROOT="/public/home/a094f4d10/voice_projects/code/n019_official"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="/public/home/a094f4d10/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"
cd "$ROOT"
export TMPDIR="/dev/shm/n019_du_ecapa_nt_r2_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

LABEL="du_ecapa_nt_20261117"
SUFFIX="_n019_${LABEL}"
TEST_BUNDLE="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117"
TEST_RECORDS="$TEST_BUNDLE/units/unit_records.jsonl"
TEST_TARGET_MAP="$TEST_BUNDLE/target_map.jsonl"
TEST_VOCODER="$TEST_BUNDLE/assets/generator_soup2.pt"
TEST_VOCODER_SHA="ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
ASSET_ROOT="$N019_OFFICIAL_RUNS/du_ecapa_nt_20261117/test_assets"
NT_TARGET_843="$ASSET_ROOT/nt_target_843.npz"
ECAPA_TARGET_843="$ASSET_ROOT/ecapa_target_843.npz"
SOURCE_ECAPA="$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_100_ecapa_20261117/ecapa_speaker_embeddings.npz"
TARGET_ECAPA_ALL="$N019_OFFICIAL_DATA/processed/embeddings/target_speaker_mean32_ecapa_all1158_20261117/ecapa_speaker_embeddings.npz"
DURATION_MODEL="$N019_OFFICIAL_RUNS/duration_ecapa_main_20261117/best.pt"
ANON_OUT="$N019_OFFICIAL_RUNS/du_ecapa_nt_20261117/anonymised"
EVAL_OUT="$N019_OFFICIAL_RUNS/eval/${LABEL}"
WNT_OUT="$N019_OFFICIAL_RUNS/eval/${LABEL}_wnt"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc_ai/data"

for required in \
  "$TEST_RECORDS" \
  "$TEST_TARGET_MAP" \
  "$TEST_VOCODER" \
  "$NT_TARGET_843" \
  "$ECAPA_TARGET_843" \
  "$SOURCE_ECAPA" \
  "$TARGET_ECAPA_ALL" \
  "$DURATION_MODEL"; do
  test -s "$required" || {
    echo "Missing DU-ecapa-nt r2 input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$TEST_RECORDS")" = 1934
test "$(wc -l < "$TEST_TARGET_MAP")" = 1934
test "$(sha256sum "$TEST_VOCODER" | awk '{print $1}')" = "$TEST_VOCODER_SHA"
test "$(sha256sum "$NT_TARGET_843" | awk '{print $1}')" = \
  "5d00633b04e1ab4b70ebb40b657aa36c25f7809c64a5ce0333d1d2d5e14834c4"
test "$(sha256sum "$ECAPA_TARGET_843" | awk '{print $1}')" = \
  "3bab6904dda1b4feea4e8e0dc29ad9654617acf45a547eb2166bfcecd26910f2"

python - "$SOURCE_ECAPA" "$TARGET_ECAPA_ALL" "$NT_TARGET_843" \
  "$ECAPA_TARGET_843" <<'PY'
import sys

import numpy as np

source_path, target_all_path, nt_path, ecapa_path = sys.argv[1:]

def load(path):
    archive = np.load(path, allow_pickle=False)
    try:
        return {key: archive[key] for key in archive.files}
    finally:
        archive.close()

source = load(source_path)
target_all = load(target_all_path)
nt = load(nt_path)
ecapa = load(ecapa_path)
if len(source) != 251 or any(value.shape != (192,) for value in source.values()):
    raise SystemExit("Source ECAPA archive is not 251 x 192")
if len(target_all) != 1158 or any(value.shape != (192,) for value in target_all.values()):
    raise SystemExit("Full target ECAPA archive is not 1158 x 192")
if len(nt) != 843 or any(value.shape != (250,) for value in nt.values()):
    raise SystemExit("NT test subset is not 843 x 250")
if set(ecapa) != set(nt) or any(value.shape != (192,) for value in ecapa.values()):
    raise SystemExit("ECAPA test subset does not match the 843 NT keys")
if any(not np.isfinite(value).all() for value in (*source.values(), *target_all.values(), *nt.values(), *ecapa.values())):
    raise SystemExit("Non-finite embedding found")
print("DU_ECAPA_NT_R2_ASSETS_OK source=251 target_all=1158 test_keys=843")
PY

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=repair continuation for DU-ecapa-nt test"
echo "reuses source ECAPA, 30-epoch duration model, full target ECAPA and test subsets"
echo "resources=1 DCU 16 CPU 60GB wall=2h"
echo "resources_expected=0.35 worst=2.0 card-hours"
echo "outputs=$ANON_OUT $EVAL_OUT $WNT_OUT"

export N019_EVAL_LABEL="$LABEL"
export N019_EVAL_SYSTEM="DU-ecapa-nt"
export N019_EVAL_VPC_DATA="$VPC_ROOT"
export N019_EVAL_VOCODER="$TEST_VOCODER"
export N019_EVAL_VOC_SHA="$TEST_VOCODER_SHA"
export N019_EVAL_STEPS="96000"
export N019_EVAL_TARGET_EMBEDDINGS="$NT_TARGET_843"
export N019_EVAL_TARGET_EMBEDDING_KEY="target_speaker"
export N019_EVAL_TARGET_EMBEDDING_MODE="speaker_mean_l2"
export N019_EVAL_DURATION_MODE="ecapa"
export N019_EVAL_DURATION_MODEL="$DURATION_MODEL"
export N019_EVAL_DURATION_EMBEDDINGS="$ECAPA_TARGET_843"
export N019_EVAL_DURATION_EMBEDDING_KEY="target_speaker"
export N019_EVAL_ANON_OUT="$ANON_OUT"
export N019_EVAL_OUT="$EVAL_OUT"

# The self-contained bundle uses the same 1,934-row records file as both
# source manifest and unit records. Pin both expected hashes explicitly so the
# ECAPA duration checkpoint is not checked against the old DUpred checkpoint.
export N019_LIBRI_TEST_SOURCE="$TEST_RECORDS"
export N019_LIBRI_TEST_UNITS="$TEST_RECORDS"
export N019_LIBRI_TEST_TARGET_MAP="$TEST_TARGET_MAP"
export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$NT_TARGET_843"
export N019_LIBRI_TEST_TARGET_EMBEDDING_KEY="target_speaker"
export N019_LIBRI_TEST_TARGET_EMBEDDING_MODE="speaker_mean_l2"
export N019_LIBRI_TEST_DURATION_MODE="ecapa"
export N019_LIBRI_TEST_DURATION_MODEL="$DURATION_MODEL"
export N019_LIBRI_TEST_DURATION_EMBEDDINGS="$ECAPA_TARGET_843"
export N019_LIBRI_TEST_DURATION_EMBEDDING_KEY="target_speaker"
export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA="$(
  sha256sum "$TEST_RECORDS" | awk '{print $1}'
)"
export N019_LIBRI_TEST_EXPECTED_DURATION_SHA="$(
  sha256sum "$DURATION_MODEL" | awk '{print $1}'
)"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"
bash "$ROOT/scripts/run_full_eval_param_ai.sh"

export N019_VPC_DATA="$VPC_ROOT"
export N019_DATA_SUFFIX="$SUFFIX"
export N019_RUN_NAME="${LABEL}_wnt"
export N019_WNT_ATTACKS="I L"
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$WNT_OUT"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"

python - "$EVAL_OUT" "$WNT_OUT" <<'PY'
import json
import sys
from pathlib import Path

eval_out, wnt_out = map(Path, sys.argv[1:])
quality = json.loads((eval_out / "quality_metrics.json").read_text(encoding="utf-8"))
wnt = json.loads((wnt_out / "summary.json").read_text(encoding="utf-8"))
result = {
    "system": "DU-ecapa-nt",
    "quality": quality["values"],
    "paper_quality": {"WER": 7.59, "UTMOS": 3.60, "WhiSQA": 3.70},
    "wnt_I": float(wnt["attacks"]["I"]["mean_eer_percent"]),
    "wnt_L": float(wnt["attacks"]["L"]["mean_eer_percent"]),
    "paper_wnt_I": 40.3,
    "paper_wnt_L": 43.0,
}
(eval_out / "du_ecapa_nt_summary.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$SOURCE_ECAPA" \
  "$TARGET_ECAPA_ALL" \
  "$DURATION_MODEL" \
  "$TEST_VOCODER" \
  "$NT_TARGET_843" \
  "$ECAPA_TARGET_843" \
  "$ANON_OUT/anon.jsonl" \
  "$EVAL_OUT/WER.json" \
  "$EVAL_OUT/mos/UTMOS.json" \
  "$EVAL_OUT/mos/WhiSQA.json" \
  "$EVAL_OUT/quality_metrics.json" \
  "$EVAL_OUT/du_ecapa_nt_summary.json" \
  "$WNT_OUT/summary.json"

echo "N019_DU_ECAPA_NT_R2_COMPLETE out=$EVAL_OUT"
