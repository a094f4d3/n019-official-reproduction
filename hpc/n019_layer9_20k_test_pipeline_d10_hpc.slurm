#!/bin/bash
#SBATCH --job-name=n019_layer9_20k_test
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=03:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="$HOME/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"
cd "$ROOT"

export TMPDIR="/dev/shm/n019_layer9_20k_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

LABEL="layer9_20k_20261117"
SUFFIX="_n019_${LABEL}"
UNITS="$HOME/voice_projects/data/n019_official/processed/units/layer9_eval_20261116/test/unit_records.jsonl"
SOURCE="/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/libri_test.jsonl"
TARGET_MAP="/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl"
DURATION_MODEL="$N019_OFFICIAL_RUNS/duration_pred_layer9_aligned_20261116/best.pt"
VOCODER="$N019_OFFICIAL_RUNS/vocoder_nt_layer9_aligned_pilot_20261116/snapshots/generator_step00020000.pt"
TARGET_EMBEDDINGS="$N019_OFFICIAL_RUNS/layer9_step8k_test_20261117/target_speaker_mean32_shrink01_843.npz"
OUT="$N019_OFFICIAL_RUNS/layer9_step20k_test_20261117"
EVAL_OUT="$OUT/eval"
WNT_OUT="$OUT/wnt_il"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"

for required in \
  "$UNITS" \
  "$SOURCE" \
  "$TARGET_MAP" \
  "$DURATION_MODEL" \
  "$VOCODER" \
  "$TARGET_EMBEDDINGS"; do
  test -s "$required" || {
    echo "Missing layer-9 20k input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$UNITS")" = 1934
test "$(wc -l < "$SOURCE")" = 1934
test "$(wc -l < "$TARGET_MAP")" = 1934

SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"
test "$VOCODER_SHA" = "34f4c46b2e85373585340e0d9b6fc04e72fc9b2d0398edf2181c4b3d233d6b84"

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=full test screen for the fixed-dev-selected layer-9 step 20000 checkpoint"
echo "resources=1 DCU 16 CPU 60GB wall=3h"
echo "vocoder=$VOCODER"
echo "vocoder_sha256=$VOCODER_SHA"
echo "duration=$DURATION_MODEL"
echo "outputs=$OUT"

export N019_LIBRI_TEST_SOURCE="$SOURCE"
export N019_LIBRI_TEST_UNITS="$UNITS"
export N019_LIBRI_TEST_TARGET_MAP="$TARGET_MAP"
export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$TARGET_EMBEDDINGS"
export N019_LIBRI_TEST_TARGET_EMBEDDING_KEY=target_speaker
export N019_LIBRI_TEST_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1
export N019_LIBRI_TEST_DURATION_MODE=pred
export N019_LIBRI_TEST_DURATION_MODEL="$DURATION_MODEL"
export N019_LIBRI_TEST_VOCODER="$VOCODER"
export N019_LIBRI_TEST_VPC_DATA="$VPC_ROOT"
export N019_LIBRI_TEST_ANON_OUT="$OUT/anonymised"
export N019_LIBRI_TEST_SUFFIX="$SUFFIX"
export N019_LIBRI_TEST_VERIFY="$OUT/verification.json"
export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA="$SOURCE_SHA"
export N019_LIBRI_TEST_EXPECTED_DURATION_SHA="$DURATION_SHA"
export N019_LIBRI_TEST_EXPECTED_VOCODER_SHA="$VOCODER_SHA"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"
bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

export N019_EVAL_LABEL="$LABEL"
export N019_EVAL_SYSTEM="DU-pred-nt-layer9_20k_20261117"
export N019_EVAL_STEPS=20000
export N019_EVAL_VOCODER="$VOCODER"
export N019_EVAL_VOC_SHA="$VOCODER_SHA"
export N019_EVAL_TARGET_EMBEDDINGS="$TARGET_EMBEDDINGS"
export N019_EVAL_TARGET_EMBEDDING_KEY=target_speaker
export N019_EVAL_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1
export N019_EVAL_DURATION_MODE=pred
export N019_EVAL_DURATION_MODEL="$DURATION_MODEL"
export N019_EVAL_VPC_DATA="$VPC_ROOT"
export N019_EVAL_ANON_OUT="$OUT/anonymised"
export N019_EVAL_OUT="$EVAL_OUT"
bash "$ROOT/scripts/run_full_eval_param_ai.sh"

export N019_DATA_SUFFIX="$SUFFIX"
export N019_VPC_DATA="$VPC_ROOT"
export N019_WNT_BASE_VPC_DATA="$VPC_ROOT"
export N019_WNT_ATTACKS="I L"
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$WNT_OUT"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"

python - "$EVAL_OUT" "$WNT_OUT" "$VOCODER" "$DURATION_MODEL" <<'PY'
import json
import sys
from pathlib import Path

eval_out, wnt_out = map(Path, sys.argv[1:3])
quality = json.loads((eval_out / "quality_metrics.json").read_text(encoding="utf-8"))
wnt = json.loads((wnt_out / "summary.json").read_text(encoding="utf-8"))
result = {
    "system": "DU-pred-nt-layer9_20k_20261117",
    "quality": quality["values"],
    "paper_quality": {"WER": 7.41, "UTMOS": 3.63, "WhiSQA": 3.69},
    "wnt_I": float(wnt["attacks"]["I"]),
    "wnt_L": float(wnt["attacks"]["L"]),
    "paper_wnt_I": 39.9,
    "paper_wnt_L": 42.3,
    "vocoder": sys.argv[3],
    "duration_model": sys.argv[4],
}
(eval_out / "layer9_20k_summary.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$VOCODER" \
  "$DURATION_MODEL" \
  "$TARGET_EMBEDDINGS" \
  "$OUT/anonymised/anon.jsonl" \
  "$OUT/verification.json" \
  "$EVAL_OUT/WER.json" \
  "$EVAL_OUT/mos/UTMOS.json" \
  "$EVAL_OUT/mos/WhiSQA.json" \
  "$EVAL_OUT/quality_metrics.json" \
  "$EVAL_OUT/layer9_20k_summary.json" \
  "$WNT_OUT/summary.json"

echo "N019_LAYER9_20K_TEST_COMPLETE out=$OUT"
