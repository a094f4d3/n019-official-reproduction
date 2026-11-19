#!/usr/bin/env bash
#SBATCH --job-name=n019_crossspkeval
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=01:30:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="${N019_VOICE_ROOT:-$HOME/voice_projects}"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS" "$N019_OFFICIAL_RUNS"
cd "$ROOT"

export TMPDIR="${TMPDIR:-/dev/shm/n019_crossspkeval_${SLURM_JOB_ID:-manual}}"
mkdir -p "$TMPDIR"

CHECKPOINT="${N019_CROSSSPEAKER_CHECKPOINT:?Set N019_CROSSSPEAKER_CHECKPOINT}"
CHECKPOINT_SHA="${N019_CROSSSPEAKER_CHECKPOINT_SHA256:?Set N019_CROSSSPEAKER_CHECKPOINT_SHA256}"
LABEL="${N019_CROSSSPEAKER_LABEL:?Set N019_CROSSSPEAKER_LABEL}"
SUFFIX="_n019_${LABEL}"

TEST_BUNDLE="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117"
TEST_RECORDS="$TEST_BUNDLE/units/unit_records.jsonl"
TEST_TARGET_MAP="$TEST_BUNDLE/target_map.jsonl"
TARGET_EMBEDDINGS="$N019_OFFICIAL_DATA/processed/embeddings/nt_ecapa_residual_test_20261117/residual_0p25.npz"
TARGET_EMBEDDINGS_SHA="dc342ad39027937be3a6bb728ccb85f0026badda45cb95b764e33c7f92044122"
DURATION_MODEL="$N019_OFFICIAL_DATA/processed/selection_dev100_40spk/duration_pred_paperfix_best.pt"
DURATION_SHA="8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
ANON_OUT="$N019_OFFICIAL_RUNS/eval/${LABEL}/anonymised"
EVAL_OUT="$N019_OFFICIAL_RUNS/eval/${LABEL}"
WNT_OUT="$N019_OFFICIAL_RUNS/eval/${LABEL}_wnt"

for required in \
  "$CHECKPOINT" "$TEST_RECORDS" "$TEST_TARGET_MAP" \
  "$TARGET_EMBEDDINGS" "$DURATION_MODEL" \
  "$VPC_ROOT/libri_test/wav.scp"; do
  test -s "$required" || {
    echo "Missing cross-speaker evaluation input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$TEST_RECORDS")" = 1934
test "$(wc -l < "$TEST_TARGET_MAP")" = 1934
test "$(sha256sum "$CHECKPOINT" | awk '{print $1}')" = "$CHECKPOINT_SHA"
test "$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')" = "$TARGET_EMBEDDINGS_SHA"
test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = "$DURATION_SHA"

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=cross-speaker fine-tuned vocoder full test quality and W-NT I/L"
echo "label=$LABEL checkpoint=$CHECKPOINT sha256=$CHECKPOINT_SHA"
echo "target_embeddings=residual0.25 duration=pred"
echo "wall=1.5h expected=0.3 worst=1.5 card-hours"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"
mkdir -p "$EVAL_OUT"

SOURCE_SHA="$(sha256sum "$TEST_RECORDS" | awk '{print $1}')"

export N019_LIBRI_TEST_SOURCE="$TEST_RECORDS"
export N019_LIBRI_TEST_UNITS="$TEST_RECORDS"
export N019_LIBRI_TEST_TARGET_MAP="$TEST_TARGET_MAP"
export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$TARGET_EMBEDDINGS"
export N019_LIBRI_TEST_TARGET_EMBEDDING_KEY="target_speaker"
export N019_LIBRI_TEST_TARGET_EMBEDDING_MODE="speaker_mean_l2"
export N019_LIBRI_TEST_DURATION_MODE="pred"
export N019_LIBRI_TEST_DURATION_MODEL="$DURATION_MODEL"
export N019_LIBRI_TEST_VOCODER="$CHECKPOINT"
export N019_LIBRI_TEST_VPC_DATA="$VPC_ROOT"
export N019_LIBRI_TEST_ANON_OUT="$ANON_OUT"
export N019_LIBRI_TEST_SUFFIX="$SUFFIX"
export N019_LIBRI_TEST_VERIFY="$EVAL_OUT/verification.json"
export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA="$SOURCE_SHA"
export N019_LIBRI_TEST_EXPECTED_DURATION_SHA="$DURATION_SHA"
export N019_LIBRI_TEST_EXPECTED_VOCODER_SHA="$CHECKPOINT_SHA"
export N019_SPEAKER_EMBEDDING_SCALE=1.0

bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

export N019_EVAL_LABEL="$LABEL"
export N019_EVAL_SYSTEM="DU-pred-nt-crossspeaker"
export N019_EVAL_STEPS=96000
export N019_EVAL_VOCODER="$CHECKPOINT"
export N019_EVAL_VOC_SHA="$CHECKPOINT_SHA"
export N019_EVAL_TARGET_EMBEDDINGS="$TARGET_EMBEDDINGS"
export N019_EVAL_TARGET_EMBEDDING_KEY="target_speaker"
export N019_EVAL_TARGET_EMBEDDING_MODE="speaker_mean_l2"
export N019_EVAL_DURATION_MODE="pred"
export N019_EVAL_DURATION_MODEL="$DURATION_MODEL"
export N019_EVAL_VPC_DATA="$VPC_ROOT"
export N019_EVAL_ANON_OUT="$ANON_OUT"
export N019_EVAL_OUT="$EVAL_OUT"
bash "$ROOT/scripts/run_full_eval_param_ai.sh"

export N019_DATA_SUFFIX="$SUFFIX"
export N019_VPC_DATA="$VPC_ROOT"
export N019_WNT_BASE_VPC_DATA="$VPC_ROOT"
export N019_WNT_ATTACKS="I L"
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$WNT_OUT"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"

python - "$EVAL_OUT" "$WNT_OUT" "$CHECKPOINT" "$CHECKPOINT_SHA" <<'PY'
import json
import sys
from pathlib import Path

eval_out = Path(sys.argv[1])
wnt_out = Path(sys.argv[2])
quality = json.loads((eval_out / "quality_metrics.json").read_text(encoding="utf-8"))
wnt = json.loads((wnt_out / "summary.json").read_text(encoding="utf-8"))
result = {
    "system": "DU-pred-nt-crossspeaker",
    "checkpoint": sys.argv[3],
    "checkpoint_sha256": sys.argv[4],
    "quality": quality["values"],
    "paper_quality": {"WER": 7.41, "UTMOS": 3.63, "WhiSQA": 3.69},
    "wnt_I": float(wnt["attacks"]["I"]["mean_eer_percent"]),
    "wnt_L": float(wnt["attacks"]["L"]["mean_eer_percent"]),
    "paper_wnt_I": 39.9,
    "paper_wnt_L": 42.3,
}
(eval_out / "cross_speaker_summary.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$CHECKPOINT" \
  "$ANON_OUT/anon.jsonl" \
  "$EVAL_OUT/WER.json" \
  "$EVAL_OUT/mos/UTMOS.json" \
  "$EVAL_OUT/mos/WhiSQA.json" \
  "$EVAL_OUT/quality_metrics.json" \
  "$EVAL_OUT/cross_speaker_summary.json" \
  "$WNT_OUT/summary.json"
echo "N019_CROSS_SPEAKER_FULL_EVAL_COMPLETE out=$EVAL_OUT"
