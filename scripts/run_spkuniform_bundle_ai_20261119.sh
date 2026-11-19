#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

WORK="/dev/shm/n019_spkuniform_bundle_$(date +%s)_$$"
PUBLIC_OUT="$N019_OFFICIAL_RUNS/spkuniform_bundle_screen_20261119"
BUNDLE="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117"
RECORDS="$BUNDLE/units/unit_records.jsonl"
VOCODER="$BUNDLE/assets/generator_soup2.pt"
DURATION="$BUNDLE/assets/duration_pred_paperfix_best.pt"
TARGET_MAP="$N019_OFFICIAL_DATA/processed/targets/libri_test_spkuniform1158_seed20261119.jsonl"
TARGET_EMBEDDINGS="$N019_OFFICIAL_DATA/processed/embeddings/libri_test_spkuniform1158_residual0p5_seed20261119.npz"
VPC_BASE="$N019_OFFICIAL_DATA/vpc_ai/data"

mkdir -p "$WORK" "$PUBLIC_OUT"
export TMPDIR="$WORK/tmp"
mkdir -p "$TMPDIR"
cp -a "$VPC_BASE" "$WORK/vpc"

for required in \
  "$RECORDS" "$VOCODER" "$DURATION" "$TARGET_MAP" \
  "$TARGET_EMBEDDINGS" "$WORK/vpc/libri_test/wav.scp" \
  "$WORK/vpc/libri_test_enrolls/wav.scp" \
  "$WORK/vpc/libri_test_trials_f/wav.scp" \
  "$WORK/vpc/libri_test_trials_m/wav.scp"; do
  test -s "$required" || {
    echo "Missing speaker-uniform bundle input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$RECORDS")" = 1934
test "$(find "$BUNDLE/units/codes" -maxdepth 1 -type f -name '*.npy' | wc -l)" = 1934
test "$(wc -l < "$TARGET_MAP")" = 1934
test "$(sha256sum "$TARGET_MAP" | awk '{print $1}')" = \
  "824cbc419855abecf4dee2cc4c52d0dc883e5b94c110dfc11dd2184889481f89"
test "$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')" = \
  "adf72f800099d6d436511d1ec977e13e68173383f53bac1162fbb0e06205dbd5"
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = \
  "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
test "$(sha256sum "$DURATION" | awk '{print $1}')" = \
  "8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"

SOURCE_SHA="$(sha256sum "$RECORDS" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION" | awk '{print $1}')"

echo "ai_task=${MARSV2_TASK_ID:-manual} host=$(hostname) date=$(date -Is)"
echo "work=$WORK public_out=$PUBLIC_OUT"
echo "target_map=$TARGET_MAP"
echo "target_embeddings=$TARGET_EMBEDDINGS"

for SPEC in "0.0:spkuniform_dur05_nocap" "1.5:spkuniform_dur05_cap15"; do
  IFS=: read -r CAP TAG <<< "$SPEC"
  LABEL="n019_${TAG}_20261119"
  SUFFIX="_n019_${LABEL}"
  OUT="$WORK/$TAG"
  mkdir -p "$OUT"
  echo "CONDITION_START tag=$TAG cap=$CAP"

  export N019_LIBRI_TEST_SOURCE="$RECORDS"
  export N019_LIBRI_TEST_UNITS="$RECORDS"
  export N019_LIBRI_TEST_TARGET_MAP="$TARGET_MAP"
  export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA="$SOURCE_SHA"
  export N019_LIBRI_TEST_EXPECTED_DURATION_SHA="$DURATION_SHA"
  export N019_EVAL_LABEL="$LABEL"
  export N019_EVAL_SYSTEM="DU-pred-nt-speaker-uniform-residual0.5-duration0.5-cap${CAP}"
  export N019_EVAL_VPC_DATA="$WORK/vpc"
  export N019_EVAL_VOCODER="$VOCODER"
  export N019_EVAL_VOC_SHA="$VOCODER_SHA"
  export N019_EVAL_STEPS=96000
  export N019_EVAL_TARGET_EMBEDDINGS="$TARGET_EMBEDDINGS"
  export N019_EVAL_TARGET_EMBEDDING_KEY=target_speaker
  export N019_EVAL_TARGET_EMBEDDING_MODE=speaker_mean_l2
  export N019_EVAL_DURATION_MODE=pred
  export N019_EVAL_DURATION_MODEL="$DURATION"
  export N019_EVAL_ANON_OUT="$OUT/anonymised"
  export N019_EVAL_OUT="$OUT/eval"
  export N019_WNT_OUT="$OUT/wnt_il"
  export N019_SPEAKER_EMBEDDING_SCALE=1.0
  export N019_DURATION_EXTRAPOLATION=0.5
  export N019_DURATION_PRESERVE_TOTAL=1
  export N019_DURATION_SOFT_CAP_FRAMES="$CAP"

  bash "$ROOT/scripts/run_full_eval_param_ai.sh"

  export N019_VPC_DATA="$WORK/vpc"
  export N019_WNT_BASE_VPC_DATA="$WORK/vpc"
  export N019_DATA_SUFFIX="$SUFFIX"
  export N019_WNT_ATTACKS="I L"
  export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
  bash "$ROOT/scripts/evaluate_wnt_remote.sh"

  python - "$OUT/eval" "$OUT/wnt_il" "$CAP" "$OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

quality = json.loads(
    (Path(sys.argv[1]) / "quality_metrics.json").read_text(encoding="utf-8")
)
wnt = json.loads(
    (Path(sys.argv[2]) / "summary.json").read_text(encoding="utf-8")
)
result = {
    "duration_soft_cap_frames": float(sys.argv[3]),
    "duration_extrapolation": 0.5,
    "preserve_predicted_total": True,
    "residual_strength": 0.5,
    "quality": quality["values"],
    "wnt_I": float(wnt["attacks"]["I"]["mean_eer_percent"]),
    "wnt_L": float(wnt["attacks"]["L"]["mean_eer_percent"]),
    "paper": {
        "WER": 7.41,
        "UTMOS": 3.63,
        "WhiSQA": 3.69,
        "W-NT_I": 39.9,
        "W-NT_L": 42.3,
    },
}
Path(sys.argv[4]).write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

  mkdir -p "$PUBLIC_OUT/$TAG"
  cp "$OUT/summary.json" "$PUBLIC_OUT/$TAG/summary.json"
  cp "$OUT/eval/quality_metrics.json" "$PUBLIC_OUT/$TAG/quality_metrics.json"
  cp "$OUT/wnt_il/summary.json" "$PUBLIC_OUT/$TAG/wnt_il_summary.json"
  sha256sum "$OUT/summary.json" "$OUT/eval/quality_metrics.json" \
    "$OUT/wnt_il/summary.json" > "$PUBLIC_OUT/$TAG/SHA256SUMS.txt"
  echo "CONDITION_COMPLETE tag=$TAG cap=$CAP"
done

python - "$WORK" "$PUBLIC_OUT/screen_summary.json" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
results = []
for path in sorted(root.glob("*/summary.json")):
    results.append(json.loads(path.read_text(encoding="utf-8")))
destination = Path(sys.argv[2])
destination.write_text(
    json.dumps({"results": results}, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps({"results": results}, indent=2, sort_keys=True))
PY
sha256sum "$PUBLIC_OUT/screen_summary.json" "$PUBLIC_OUT"/*/summary.json \
  > "$PUBLIC_OUT/SHA256SUMS.txt"
cat "$PUBLIC_OUT/SHA256SUMS.txt"
echo "N019_SPKUNIFORM_BUNDLE_SCREEN_COMPLETE work=$WORK public_out=$PUBLIC_OUT"
