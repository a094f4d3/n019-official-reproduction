#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-/public/home/a094f4d10/voice_projects/code/n019_official}"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SOURCE=/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/libri_test.jsonl
UNITS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libri_test_paperfix/unit_records.jsonl
TARGET_MAP=/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl
TARGET_EMBEDDINGS=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/nt_ecapa_residual_test_20261117/residual_0p5.npz
DURATION_MODEL=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt
VOCODER=/public/home/a094f4d10/voice_projects/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
OUT_ROOT="$N019_OFFICIAL_RUNS/softcap_remaining_20261119"

for required in \
  "$SOURCE" "$UNITS" "$TARGET_MAP" "$TARGET_EMBEDDINGS" \
  "$DURATION_MODEL" "$VOCODER" \
  "$VPC_ROOT/libri_test/wav.scp"; do
  test -s "$required"
done

test "$(wc -l < "$SOURCE")" = 1934
test "$(wc -l < "$UNITS")" = 1934
test "$(wc -l < "$TARGET_MAP")" = 1934
test "$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')" = \
  7a015304bebdcd12bcb4deda5792ea1941159650eff4c97367716b0748e690ef
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = \
  ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6
test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = \
  8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c

mkdir -p "$OUT_ROOT"
echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=complete the untried soft-cap 1.0 and 1.5 points"
echo "residual=0.5 duration_extrapolation=0.5 preserve_total=1"
echo "caps=1.0 1.5"
echo "wall=2h expected=0.60 worst=2.00 card-hours"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"
SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"

for CAP in 1.0 1.5; do
  TAG="res05_dur05_cap${CAP//./p}"
  LABEL="n019_${TAG}_20261119"
  SUFFIX="_n019_${LABEL}"
  OUT="$OUT_ROOT/$TAG"
  mkdir -p "$OUT"
  echo "SOFTCAP_REMAINING_START cap=$CAP out=$OUT"

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
  export N019_DURATION_EXTRAPOLATION=0.5
  export N019_DURATION_PRESERVE_TOTAL=1
  export N019_DURATION_SOFT_CAP_FRAMES="$CAP"
  bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

  export N019_EVAL_LABEL="$LABEL"
  export N019_EVAL_SYSTEM="DU-pred-nt-residual0.5-durextra0.5-softcap${CAP}"
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
  export N019_EVAL_OUT="$OUT/quality"
  bash "$ROOT/scripts/run_full_eval_param_ai.sh"

  export N019_DATA_SUFFIX="$SUFFIX"
  export N019_VPC_DATA="$VPC_ROOT"
  export N019_WNT_BASE_VPC_DATA="$VPC_ROOT"
  export N019_WNT_ATTACKS="I L"
  export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
  export N019_WNT_OUT="$OUT/wnt_il"
  bash "$ROOT/scripts/evaluate_wnt_remote.sh"

  python - "$OUT/quality" "$OUT/wnt_il" "$CAP" "$OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

quality = json.loads(
    (Path(sys.argv[1]) / "quality_metrics.json").read_text(encoding="utf-8")
)
wnt = json.loads(
    (Path(sys.argv[2]) / "summary.json").read_text(encoding="utf-8")
)
destination = Path(sys.argv[4])
result = {
    "residual_strength": 0.5,
    "duration_extrapolation": 0.5,
    "duration_soft_cap_frames": float(sys.argv[3]),
    "preserve_predicted_total": True,
    "quality": quality["values"],
    "wnt_I": float(wnt["attacks"]["I"]["mean_eer_percent"]),
    "wnt_L": float(wnt["attacks"]["L"]["mean_eer_percent"]),
}
destination.write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

  sha256sum \
    "$OUT/anonymised/anon.jsonl" \
    "$OUT/quality/quality_metrics.json" \
    "$OUT/wnt_il/summary.json" \
    "$OUT/summary.json"
  echo "SOFTCAP_REMAINING_COMPLETE cap=$CAP"
done

echo "N019_SOFTCAP_REMAINING_COMPLETE out=$OUT_ROOT"
