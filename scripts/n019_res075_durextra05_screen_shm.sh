#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

WORK="/dev/shm/n019_res075_durextra05_${SLURM_JOB_ID:-manual}"
ASSETS="$WORK/assets"
VPC_ROOT="$WORK/vpc"
OUT="$WORK/test"
mkdir -p "$WORK/tmp" "$ASSETS" "$VPC_ROOT"
export TMPDIR="$WORK/tmp"

SOURCE=/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/libri_test.jsonl
UNITS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libri_test_paperfix/unit_records.jsonl
TARGET_MAP=/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl
SOURCE_NT=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz
SOURCE_ECAPA=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/librispeech_train_clean_100_ecapa_20261117/ecapa_speaker_embeddings.npz
TARGET_NT=/public/home/a094f4d10/voice_projects/runs/n019_official/layer9_step8k_test_20261117/target_speaker_mean32_shrink01_843.npz
TARGET_ECAPA=/public/home/a094f4d10/voice_projects/runs/n019_official/du_ecapa_nt_20261117/test_assets/ecapa_target_843.npz
DURATION_MODEL=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt
VOCODER=/public/home/a094f4d10/voice_projects/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt
VPC_SOURCE="$N019_OFFICIAL_DATA/vpc/data"
LABEL=ntecres0p75_durextra0p5_20261118
SUFFIX="_n019_${LABEL}"

for required in \
  "$SOURCE" "$UNITS" "$TARGET_MAP" \
  "$SOURCE_NT" "$SOURCE_ECAPA" "$TARGET_NT" "$TARGET_ECAPA" \
  "$DURATION_MODEL" "$VOCODER" \
  "$VPC_SOURCE/libri_test/wav.scp" \
  "$VPC_SOURCE/libri_test_enrolls/wav.scp" \
  "$VPC_SOURCE/libri_test_trials_f/wav.scp" \
  "$VPC_SOURCE/libri_test_trials_f/trials" \
  "$VPC_SOURCE/libri_test_trials_m/wav.scp" \
  "$VPC_SOURCE/libri_test_trials_m/trials"; do
  test -s "$required" || {
    echo "Missing residual0.75 input: $required" >&2
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

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=non-duplicate residual0.75 plus local-rhythm extrapolation0.5 screen"
echo "work=$WORK"
echo "wall=uses parent allocation expected<=0.35 incremental card-hours"

python -u "$ROOT/scripts/build_nt_ecapa_residual_embeddings.py" \
  --source-nt "$SOURCE_NT" \
  --source-ecapa "$SOURCE_ECAPA" \
  --target-nt "$TARGET_NT" \
  --target-ecapa "$TARGET_ECAPA" \
  --out-dir "$ASSETS" \
  --ridge-weight 30000 \
  --strengths 0.75

TARGET_EMBEDDINGS="$ASSETS/residual_0p75.npz"
TARGET_EMBEDDING_SHA="$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')"
SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

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

bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

export N019_EVAL_LABEL="$LABEL"
export N019_EVAL_SYSTEM="DU-pred-nt-residual075-durextra-0.5"
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

python - "$OUT/eval" "$OUT/wnt_il" "$TARGET_EMBEDDINGS" \
  "$TARGET_EMBEDDING_SHA" "$OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

eval_out = Path(sys.argv[1])
wnt_out = Path(sys.argv[2])
destination = Path(sys.argv[5])
quality = json.loads((eval_out / "quality_metrics.json").read_text(encoding="utf-8"))
wnt = json.loads((wnt_out / "summary.json").read_text(encoding="utf-8"))
result = {
    "residual_strength": 0.75,
    "duration_extrapolation": 0.5,
    "preserve_predicted_total": True,
    "target_embeddings": sys.argv[3],
    "target_embeddings_sha256": sys.argv[4],
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
  "$TARGET_EMBEDDINGS" \
  "$OUT/anonymised/anon.jsonl" \
  "$OUT/verification.json" \
  "$OUT/eval/quality_metrics.json" \
  "$OUT/wnt_il/summary.json" \
  "$OUT/summary.json"
echo "N019_RESIDUAL075_DUREXTRA05_SCREEN_COMPLETE out=$OUT"
