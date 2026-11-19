#!/usr/bin/env bash
#SBATCH --job-name=n019_condscl
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=01:30:00
#SBATCH --output=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_condscl_%j.out
#SBATCH --error=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_condscl_%j.err

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
mkdir -p "$N019_OFFICIAL_LOGS" "$N019_OFFICIAL_RUNS"

export TMPDIR="/dev/shm/n019_condscl_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

SOURCE=/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/libri_test.jsonl
UNITS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libri_test_paperfix/unit_records.jsonl
TARGET_MAP=/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl
TARGET_EMBEDDINGS=/public/home/a094f4d10/voice_projects/runs/n019_official/layer9_step8k_test_20261117/target_speaker_mean32_shrink01_843.npz
DURATION_MODEL=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt
VOCODER=/public/home/a094f4d10/voice_projects/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
ROOT_OUT="$N019_OFFICIAL_RUNS/conditioning_scale_screen_20261117"

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
    echo "Missing conditioning-scale input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$SOURCE")" = 1934
test "$(wc -l < "$UNITS")" = 1934
test "$(wc -l < "$TARGET_MAP")" = 1934

SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"
EMBEDDING_SHA="$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')"
test "$VOCODER_SHA" = "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
test "$DURATION_SHA" = "8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"
test "$EMBEDDING_SHA" = "5d00633b04e1ab4b70ebb40b657aa36c25f7809c64a5ce0333d1d2d5e14834c4"

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=vocoder target-speaker conditioning-strength screen"
echo "formal baseline scale=1.0 is already measured; this job tests 1.5 and 2.0"
echo "source=$SOURCE"
echo "units=$UNITS"
echo "target_map=$TARGET_MAP"
echo "target_embeddings=$TARGET_EMBEDDINGS sha256=$EMBEDDING_SHA"
echo "duration=$DURATION_MODEL sha256=$DURATION_SHA"
echo "vocoder=$VOCODER sha256=$VOCODER_SHA"
echo "wall=1.5h expected=0.4 worst=1.5 card-hours"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

for SCALE in 1.5 2.0; do
  LABEL="condscl${SCALE/./p}_20261117"
  OUT="$ROOT_OUT/$LABEL"
  EVAL_OUT="$OUT/eval"
  WNT_OUT="$OUT/wnt_il"
  SUFFIX="_n019_${LABEL}"

  mkdir -p "$OUT"
  echo "CONDITIONING_SCALE_START scale=$SCALE out=$OUT"

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
  export N019_SPEAKER_EMBEDDING_SCALE="$SCALE"

  bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

  export N019_EVAL_LABEL="$LABEL"
  export N019_EVAL_SYSTEM="DU-pred-nt-conditioning-scale-$SCALE"
  export N019_EVAL_STEPS=96000
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

  python - "$EVAL_OUT" "$WNT_OUT" "$SCALE" "$OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

eval_out = Path(sys.argv[1])
wnt_out = Path(sys.argv[2])
scale = float(sys.argv[3])
destination = Path(sys.argv[4])
quality = json.loads((eval_out / "quality_metrics.json").read_text(encoding="utf-8"))
wnt = json.loads((wnt_out / "summary.json").read_text(encoding="utf-8"))
result = {
    "conditioning_scale": scale,
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
    "$EVAL_OUT/WER.json" \
    "$EVAL_OUT/mos/UTMOS.json" \
    "$EVAL_OUT/mos/WhiSQA.json" \
    "$EVAL_OUT/quality_metrics.json" \
    "$WNT_OUT/summary.json" \
    "$OUT/summary.json"
  echo "CONDITIONING_SCALE_COMPLETE scale=$SCALE out=$OUT"
done

echo "N019_CONDITIONING_SCALE_SCREEN_COMPLETE out=$ROOT_OUT"
