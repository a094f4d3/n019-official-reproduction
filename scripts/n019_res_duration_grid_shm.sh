#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

WORK="/dev/shm/n019_res_duration_grid_${SLURM_JOB_ID:-manual}"
ASSETS="$WORK/assets"
VPC_ROOT="$WORK/vpc"
OUT_ROOT="$WORK/screens"
mkdir -p "$WORK/tmp" "$ASSETS" "$VPC_ROOT" "$OUT_ROOT" "$WORK/logs" "$WORK/runs"
export TMPDIR="$WORK/tmp"
export N019_OFFICIAL_LOGS="$WORK/logs"
export N019_OFFICIAL_RUNS="$WORK/runs"

SOURCE=/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/libri_test.jsonl
UNITS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libri_test_paperfix/unit_records.jsonl
TARGET_MAP=/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl
SOURCE_NT=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz
SOURCE_ECAPA=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/librispeech_train_clean_100_ecapa_20261117/ecapa_speaker_embeddings.npz
TARGET_NT=/public/home/a094f4d10/voice_projects/runs/n019_official/layer9_step8k_test_20261117/target_speaker_mean32_shrink01_843.npz
TARGET_ECAPA=/public/home/a094f4d10/voice_projects/runs/n019_official/du_ecapa_nt_20261117/test_assets/ecapa_target_843.npz
TARGET_050=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/nt_ecapa_residual_test_20261117/residual_0p5.npz
DURATION_MODEL=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt
VOCODER=/public/home/a094f4d10/voice_projects/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt
VPC_SOURCE="$N019_OFFICIAL_DATA/vpc/data"

for required in \
  "$SOURCE" "$UNITS" "$TARGET_MAP" \
  "$SOURCE_NT" "$SOURCE_ECAPA" "$TARGET_NT" "$TARGET_ECAPA" \
  "$TARGET_050" "$DURATION_MODEL" "$VOCODER" \
  "$VPC_SOURCE/libri_test/wav.scp" \
  "$VPC_SOURCE/libri_test_enrolls/wav.scp" \
  "$VPC_SOURCE/libri_test_trials_f/wav.scp" \
  "$VPC_SOURCE/libri_test_trials_f/trials" \
  "$VPC_SOURCE/libri_test_trials_m/wav.scp" \
  "$VPC_SOURCE/libri_test_trials_m/trials"; do
  test -s "$required" || {
    echo "Missing grid input: $required" >&2
    exit 1
  }
done

for dataset in \
  libri_test \
  libri_test_enrolls \
  libri_test_trials_f \
  libri_test_trials_m; do
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
test "$(sha256sum "$TARGET_050" | awk '{print $1}')" = \
  "7a015304bebdcd12bcb4deda5792ea1941159650eff4c97367716b0748e690ef"
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = \
  "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = \
  "8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"

python -u "$ROOT/scripts/build_nt_ecapa_residual_embeddings.py" \
  --source-nt "$SOURCE_NT" \
  --source-ecapa "$SOURCE_ECAPA" \
  --target-nt "$TARGET_NT" \
  --target-ecapa "$TARGET_ECAPA" \
  --out-dir "$ASSETS" \
  --ridge-weight 30000 \
  --strengths 0.75

TARGET_075="$ASSETS/residual_0p75.npz"
SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

for SPEC in "0.5:0.6:res05_dur06" "0.5:0.65:res05_dur065" "0.75:0.6:res075_dur06"; do
  IFS=: read -r RESIDUAL DURATION TAG <<< "$SPEC"
  if [[ "$RESIDUAL" == "0.5" ]]; then
    TARGET_EMBEDDINGS="$TARGET_050"
  else
    TARGET_EMBEDDINGS="$TARGET_075"
  fi
  TARGET_EMBEDDING_SHA="$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')"
  LABEL="n019_${TAG}_20261118"
  SUFFIX="_n019_${LABEL}"
  OUT="$OUT_ROOT/$TAG"
  mkdir -p "$OUT"

  echo "GRID_START residual=$RESIDUAL duration=$DURATION out=$OUT"

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
  bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

  export N019_EVAL_LABEL="$LABEL"
  export N019_EVAL_SYSTEM="DU-pred-nt-residual${RESIDUAL}-durextra-${DURATION}"
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
  echo "GRID_COMPLETE residual=$RESIDUAL duration=$DURATION"
done

python - "$OUT_ROOT" "$WORK/grid_summary.json" <<'PY'
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

sha256sum "$WORK/grid_summary.json"
echo "N019_RES_DURATION_GRID_COMPLETE work=$WORK"
echo "Holding /dev/shm for recovery"
sleep 7200
