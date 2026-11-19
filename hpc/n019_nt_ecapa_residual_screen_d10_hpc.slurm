#!/usr/bin/env bash
#SBATCH --job-name=n019_ntecres
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=02:00:00
#SBATCH --output=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_ntecres_%j.out
#SBATCH --error=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_ntecres_%j.err

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
mkdir -p "$N019_OFFICIAL_LOGS" "$N019_OFFICIAL_RUNS"

export TMPDIR="/dev/shm/n019_ntecres_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

SOURCE=/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/libri_test.jsonl
UNITS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libri_test_paperfix/unit_records.jsonl
TARGET_MAP=/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl
SOURCE_NT=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz
SOURCE_ECAPA=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/librispeech_train_clean_100_ecapa_20261117/ecapa_speaker_embeddings.npz
TARGET_NT=/public/home/a094f4d10/voice_projects/runs/n019_official/layer9_step8k_test_20261117/target_speaker_mean32_shrink01_843.npz
TARGET_ECAPA=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/target_speaker_mean32_ecapa_all1158_20261117/ecapa_speaker_embeddings.npz
DURATION_MODEL=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt
VOCODER=/public/home/a094f4d10/voice_projects/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt
RESIDUAL_DIR="$N019_OFFICIAL_DATA/processed/embeddings/nt_ecapa_residual_test_20261117"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
OUT_ROOT="$N019_OFFICIAL_RUNS/nt_ecapa_residual_screen_20261117"

for required in \
  "$SOURCE" "$UNITS" "$TARGET_MAP" \
  "$SOURCE_NT" "$SOURCE_ECAPA" "$TARGET_NT" "$TARGET_ECAPA" \
  "$DURATION_MODEL" "$VOCODER" \
  "$VPC_ROOT/libri_test/wav.scp" \
  "$VPC_ROOT/libri_test_enrolls/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/trials" \
  "$VPC_ROOT/libri_test_trials_m/wav.scp" \
  "$VPC_ROOT/libri_test_trials_m/trials"; do
  test -s "$required" || {
    echo "Missing NT+ECAPA residual input: $required" >&2
    exit 1
  }
done

test "$(sha256sum "$SOURCE_NT" | awk '{print $1}')" = "698d128292e8abbdb0db5d39301539cfc80184b8982133566ba3bf8b6492a866"
test "$(sha256sum "$SOURCE_ECAPA" | awk '{print $1}')" = "e7f8478a2c860b59fb5591a13bba359df30438e108781eb1c71bbeb3928ae21f"
test "$(sha256sum "$TARGET_NT" | awk '{print $1}')" = "5d00633b04e1ab4b70ebb40b657aa36c25f7809c64a5ce0333d1d2d5e14834c4"
test "$(sha256sum "$TARGET_ECAPA" | awk '{print $1}')" = "74172a3a9a7d9020959954785a58f363f917a092322e458517951f9cfce0e389"
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
test "$(wc -l < "$SOURCE")" = 1934
test "$(wc -l < "$UNITS")" = 1934
test "$(wc -l < "$TARGET_MAP")" = 1934

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=NT+ECAPA timbral-residual conditioning screen"
echo "fit=paired 247 clean-100 speakers; ridge weight=30000; target=843 NT speakers"
echo "strengths=0.25 0.5"
echo "wall=2h expected=0.7 worst=2.0 card-hours"

python -u "$ROOT/scripts/build_nt_ecapa_residual_embeddings.py" \
  --source-nt "$SOURCE_NT" \
  --source-ecapa "$SOURCE_ECAPA" \
  --target-nt "$TARGET_NT" \
  --target-ecapa "$TARGET_ECAPA" \
  --out-dir "$RESIDUAL_DIR" \
  --ridge-weight 30000 \
  --strengths 0.25 0.5

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"

for SPEC in "0.25:0p25" "0.5:0p5"; do
  STRENGTH="${SPEC%%:*}"
  TAG="${SPEC##*:}"
  TARGET_EMBEDDINGS="$RESIDUAL_DIR/residual_${TAG}.npz"
  TARGET_EMBEDDING_SHA="$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')"
  LABEL="ntecres${TAG}_20261117"
  OUT="$OUT_ROOT/$LABEL"
  SUFFIX="_n019_${LABEL}"
  mkdir -p "$OUT"

  echo "NT_ECAPA_RESIDUAL_START strength=$STRENGTH out=$OUT"
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

  bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

  export N019_EVAL_LABEL="$LABEL"
  export N019_EVAL_SYSTEM="DU-pred-nt-nt-ecapa-residual-$STRENGTH"
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

  python - "$OUT/eval" "$OUT/wnt_il" "$STRENGTH" "$TARGET_EMBEDDINGS" "$TARGET_EMBEDDING_SHA" "$OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

eval_out = Path(sys.argv[1])
wnt_out = Path(sys.argv[2])
strength = float(sys.argv[3])
destination = Path(sys.argv[6])
quality = json.loads((eval_out / "quality_metrics.json").read_text(encoding="utf-8"))
wnt = json.loads((wnt_out / "summary.json").read_text(encoding="utf-8"))
result = {
    "strength": strength,
    "target_embeddings": sys.argv[4],
    "target_embeddings_sha256": sys.argv[5],
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
  echo "NT_ECAPA_RESIDUAL_COMPLETE strength=$STRENGTH out=$OUT"
done

sha256sum "$RESIDUAL_DIR/mapping_report.json"
echo "N019_NT_ECAPA_RESIDUAL_SCREEN_COMPLETE out=$OUT_ROOT"
