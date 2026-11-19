#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

WORK="/dev/shm/n019_resmid_cap15_grid_${SLURM_JOB_ID:-manual}"
VPC_ROOT="$WORK/vpc"
OUT_ROOT="$WORK/screens"
PUBLIC_OUT="$N019_OFFICIAL_RUNS/resmid_cap15_grid_20261119"
mkdir -p "$WORK/tmp" "$VPC_ROOT" "$OUT_ROOT" "$WORK/logs" "$WORK/runs" \
  "$WORK/miopen" "$PUBLIC_OUT"
export TMPDIR="$WORK/tmp"
export N019_OFFICIAL_LOGS="$WORK/logs"
export N019_OFFICIAL_RUNS="$WORK/runs"
export MIOPEN_USER_DB_PATH="$WORK/miopen"
export MIOPEN_CUSTOM_CACHE_DIR="$WORK/miopen"

SOURCE=/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/libri_test.jsonl
UNITS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libri_test_paperfix/unit_records.jsonl
TARGET_MAP=/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl
TARGET_055=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/nt_ecapa_residual_test_mid_20261119/residual_0p55.npz
TARGET_060=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/nt_ecapa_residual_test_mid_20261119/residual_0p6.npz
TARGET_065=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/nt_ecapa_residual_test_mid_20261119/residual_0p65.npz
DURATION_MODEL=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt
VOCODER="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt"
VPC_SOURCE="$N019_OFFICIAL_DATA/vpc/data"

for required in \
  "$SOURCE" "$UNITS" "$TARGET_MAP" \
  "$TARGET_055" "$TARGET_060" "$TARGET_065" \
  "$DURATION_MODEL" "$VOCODER" \
  "$VPC_SOURCE/libri_test/wav.scp" \
  "$VPC_SOURCE/libri_test_enrolls/wav.scp" \
  "$VPC_SOURCE/libri_test_trials_f/wav.scp" \
  "$VPC_SOURCE/libri_test_trials_f/trials" \
  "$VPC_SOURCE/libri_test_trials_m/wav.scp" \
  "$VPC_SOURCE/libri_test_trials_m/trials"; do
  test -s "$required" || {
    echo "Missing residual/cap grid input: $required" >&2
    exit 1
  }
done

for dataset in libri_test libri_test_enrolls libri_test_trials_f libri_test_trials_m; do
  mkdir -p "$VPC_ROOT/$dataset"
  for source_entry in "$VPC_SOURCE/$dataset"/*; do
    ln -sfn "$source_entry" "$VPC_ROOT/$dataset/$(basename "$source_entry")"
  done
done
mkdir -p "$VPC_ROOT/data/libri_test"
ln -sfn "$VPC_SOURCE/libri_test/wav" "$VPC_ROOT/data/libri_test/wav"

test "$(wc -l < "$SOURCE")" = 1934
test "$(wc -l < "$UNITS")" = 1934
test "$(wc -l < "$TARGET_MAP")" = 1934
test "$(sha256sum "$TARGET_055" | awk '{print $1}')" = \
  "855974455b79a3e699d595a36526ac39c9e469449c37d216de3978139fb9801f"
test "$(sha256sum "$TARGET_060" | awk '{print $1}')" = \
  "51e0da9794310ab09b91f99923f60512db1de6f75557f877cda06c8ee4a580f3"
test "$(sha256sum "$TARGET_065" | awk '{print $1}')" = \
  "e5d141ded74e13c4bfe77ebf7fb22af88184152d36541d3dc771e2eb5380f37d"
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = \
  "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = \
  "8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=residual0.55/0.60/0.65 around the complete candidate with soft-cap 1.5"
echo "work=$WORK public_out=$PUBLIC_OUT"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"

for SPEC in \
  "0.55:0.5:res055_dur05_cap15" \
  "0.60:0.5:res060_dur05_cap15" \
  "0.65:0.5:res065_dur05_cap15" \
  "0.65:0.6:res065_dur06_cap15"; do
  IFS=: read -r RESIDUAL DURATION TAG <<< "$SPEC"
  case "$RESIDUAL" in
    0.55) TARGET_EMBEDDINGS="$TARGET_055" ;;
    0.60) TARGET_EMBEDDINGS="$TARGET_060" ;;
    0.65) TARGET_EMBEDDINGS="$TARGET_065" ;;
    *) echo "Unexpected residual strength: $RESIDUAL" >&2; exit 1 ;;
  esac
  TARGET_EMBEDDING_SHA="$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')"
  LABEL="n019_${TAG}_20261119"
  SUFFIX="_n019_${LABEL}"
  OUT="$OUT_ROOT/$TAG"
  mkdir -p "$OUT"
  echo "GRID_START residual=$RESIDUAL duration=$DURATION cap=1.5 out=$OUT"

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
  export N019_DURATION_EXTRAPOLATION="$DURATION"
  export N019_DURATION_PRESERVE_TOTAL=1
  export N019_DURATION_SOFT_CAP_FRAMES=1.5
  bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

  export N019_EVAL_LABEL="$LABEL"
  export N019_EVAL_SYSTEM="DU-pred-nt-residual${RESIDUAL}-durextra-${DURATION}-cap1.5"
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

  python - "$OUT/eval" "$OUT/wnt_il" "$RESIDUAL" "$DURATION" \
    "$TARGET_EMBEDDINGS" "$TARGET_EMBEDDING_SHA" "$OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

eval_out = Path(sys.argv[1])
wnt_out = Path(sys.argv[2])
destination = Path(sys.argv[7])
quality = json.loads((eval_out / "quality_metrics.json").read_text(encoding="utf-8"))
wnt = json.loads((wnt_out / "summary.json").read_text(encoding="utf-8"))
result = {
    "residual_strength": float(sys.argv[3]),
    "duration_extrapolation": float(sys.argv[4]),
    "duration_soft_cap_frames": 1.5,
    "preserve_predicted_total": True,
    "target_embeddings": sys.argv[5],
    "target_embeddings_sha256": sys.argv[6],
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
destination.write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

  sha256sum \
    "$TARGET_EMBEDDINGS" \
    "$OUT/anonymised/anon.jsonl" \
    "$OUT/eval/quality_metrics.json" \
    "$OUT/wnt_il/summary.json" \
    "$OUT/summary.json"
  echo "GRID_COMPLETE residual=$RESIDUAL duration=$DURATION cap=1.5"
done

python - "$OUT_ROOT" "$PUBLIC_OUT/grid_summary.json" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
destination = Path(sys.argv[2])
results = []
for path in sorted(root.glob("*/summary.json")):
    results.append(json.loads(path.read_text(encoding="utf-8")))
destination.write_text(
    json.dumps({"results": results}, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps({"results": results}, indent=2, sort_keys=True))
PY

for tag in res055_dur05_cap15 res060_dur05_cap15 res065_dur05_cap15 res065_dur06_cap15; do
  mkdir -p "$PUBLIC_OUT/$tag"
  cp "$OUT_ROOT/$tag/summary.json" "$PUBLIC_OUT/$tag/summary.json"
  cp "$OUT_ROOT/$tag/verification.json" "$PUBLIC_OUT/$tag/verification.json"
  cp "$OUT_ROOT/$tag/eval/quality_metrics.json" "$PUBLIC_OUT/$tag/quality_metrics.json"
  cp "$OUT_ROOT/$tag/wnt_il/summary.json" "$PUBLIC_OUT/$tag/wnt_il_summary.json"
done
sha256sum "$PUBLIC_OUT/grid_summary.json" "$PUBLIC_OUT"/*/summary.json \
  > "$PUBLIC_OUT/SHA256SUMS.txt"
cat "$PUBLIC_OUT/SHA256SUMS.txt"
echo "N019_RESMID_CAP15_GRID_COMPLETE work=$WORK public_out=$PUBLIC_OUT"
