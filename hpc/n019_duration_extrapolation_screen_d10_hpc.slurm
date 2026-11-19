#!/usr/bin/env bash
#SBATCH --job-name=n019_durextra
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=01:30:00
#SBATCH --output=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_durextra_%j.out
#SBATCH --error=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_durextra_%j.err

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
mkdir -p "$N019_OFFICIAL_LOGS" "$N019_OFFICIAL_RUNS"
export TMPDIR="/dev/shm/n019_durextra_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

SOURCE=/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/libri_test.jsonl
UNITS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libri_test_paperfix/unit_records.jsonl
TARGET_MAP=/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl
TARGET_EMBEDDINGS=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/nt_ecapa_residual_test_20261117/residual_0p25.npz
DURATION_MODEL=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt
VOCODER=/public/home/a094f4d10/voice_projects/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
OUT_ROOT="$N019_OFFICIAL_RUNS/duration_extrapolation_screen_20261117"

for required in \
  "$SOURCE" "$UNITS" "$TARGET_MAP" "$TARGET_EMBEDDINGS" \
  "$DURATION_MODEL" "$VOCODER" \
  "$VPC_ROOT/libri_test/wav.scp" \
  "$VPC_ROOT/libri_test_enrolls/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/trials" \
  "$VPC_ROOT/libri_test_trials_m/wav.scp" \
  "$VPC_ROOT/libri_test_trials_m/trials"; do
  test -s "$required" || {
    echo "Missing duration-extrapolation input: $required" >&2
    exit 1
  }
done

test "$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')" = "dc342ad39027937be3a6bb728ccb85f0026badda45cb95b764e33c7f92044122"
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = "8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"
test "$(wc -l < "$SOURCE")" = 1934
test "$(wc -l < "$UNITS")" = 1934
test "$(wc -l < "$TARGET_MAP")" = 1934

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=local-rhythm extrapolation on the balanced residual0.25 candidate"
echo "strengths=0.5 1.0; preserve predicted total duration=1"
echo "wall=1.5h expected=0.6 worst=1.5 card-hours"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"
SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"

for SPEC in "0.5:0p5" "1.0:1p0"; do
  STRENGTH="${SPEC%%:*}"
  TAG="${SPEC##*:}"
  LABEL="durextra${TAG}_20261117"
  OUT="$OUT_ROOT/$LABEL"
  SUFFIX="_n019_${LABEL}"
  mkdir -p "$OUT"
  echo "DURATION_EXTRAPOLATION_START strength=$STRENGTH out=$OUT"

  export N019_LIBRI_TEST_SOURCE="$SOURCE"
  export N019_LIBRI_TEST_UNITS="$UNITS"
  export N019_LIBRI_TEST_TARGET_MAP="$TARGET_MAP"
  export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$TARGET_EMBEDDINGS"
  export N019_LIBRI_TEST_TARGET_EMBEDDING_KEY=target_speaker
  export N019_LIBRI_TEST_TARGET_EMBEDDING_MODE=speaker_mean_l2
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
  export N019_SPEAKER_EMBEDDING_SCALE=1.0
  export N019_DURATION_EXTRAPOLATION="$STRENGTH"
  export N019_DURATION_PRESERVE_TOTAL=1

  bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

  export N019_EVAL_LABEL="$LABEL"
  export N019_EVAL_SYSTEM="DU-pred-nt-residual025-durextra-$STRENGTH"
  export N019_EVAL_STEPS=96000
  export N019_EVAL_VOCODER="$VOCODER"
  export N019_EVAL_VOC_SHA="$VOCODER_SHA"
  export N019_EVAL_TARGET_EMBEDDINGS="$TARGET_EMBEDDINGS"
  export N019_EVAL_TARGET_EMBEDDING_KEY=target_speaker
  export N019_EVAL_TARGET_EMBEDDING_MODE=speaker_mean_l2
  export N019_EVAL_DURATION_MODE=pred
  export N019_EVAL_DURATION_MODEL="$DURATION_MODEL"
  export N019_EVAL_VPC_DATA="$VPC_ROOT"
  export N019_EVAL_ANON_OUT="$OUT/anonymised"
  export N019_EVAL_OUT="$OUT/eval"
  bash "$ROOT/scripts/run_full_eval_param_ai.sh"

  export N019_DATA_SUFFIX="$SUFFIX"
  export N019_VPC_DATA="$VPC_ROOT"
  export N019_WNT_BASE_VPC_DATA="$VPC_ROOT"
  export N019_WNT_ATTACKS="I L"
  export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
  export N019_WNT_OUT="$OUT/wnt_il"
  bash "$ROOT/scripts/evaluate_wnt_remote.sh"

  python - "$OUT/eval" "$OUT/wnt_il" "$STRENGTH" "$OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

eval_out = Path(sys.argv[1])
wnt_out = Path(sys.argv[2])
strength = float(sys.argv[3])
destination = Path(sys.argv[4])
quality = json.loads((eval_out / "quality_metrics.json").read_text(encoding="utf-8"))
wnt = json.loads((wnt_out / "summary.json").read_text(encoding="utf-8"))
result = {
    "duration_extrapolation": strength,
    "preserve_predicted_total": True,
    "quality": quality["values"],
    "paper_quality": {"WER": 7.41, "UTMOS": 3.63, "WhiSQA": 3.69},
    "wnt_I": float(wnt["attacks"]["I"]["mean_eer_percent"]),
    "wnt_L": float(wnt["attacks"]["L"]["mean_eer_percent"]),
    "paper_wnt_I": 39.9,
    "paper_wnt_L": 42.3,
}
destination.write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

  sha256sum \
    "$OUT/anonymised/anon.jsonl" \
    "$OUT/verification.json" \
    "$OUT/eval/quality_metrics.json" \
    "$OUT/wnt_il/summary.json" \
    "$OUT/summary.json"
  echo "DURATION_EXTRAPOLATION_COMPLETE strength=$STRENGTH out=$OUT"
done

echo "N019_DURATION_EXTRAPOLATION_SCREEN_COMPLETE out=$OUT_ROOT"
