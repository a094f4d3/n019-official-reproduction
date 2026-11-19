#!/usr/bin/env bash
#SBATCH --job-name=n019_scl15ft
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=02:30:00
#SBATCH --output=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_scl15ft_%j.out
#SBATCH --error=/public/home/a094f4d10/voice_projects/logs/n019_official/n019_scl15ft_%j.err

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
mkdir -p "$N019_OFFICIAL_LOGS" "$N019_OFFICIAL_RUNS"

export TMPDIR="/dev/shm/n019_scl15ft_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

TRAIN_OUT="$N019_OFFICIAL_RUNS/vocoder_nt_speaker_scale15_ft_20261117"
RECORDS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libritts_train_clean_100/unit_records.jsonl
EMBEDDINGS=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz
INIT_GENERATOR=/public/home/a094f4d10/voice_projects/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt
INIT_SHA=ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6

SOURCE=/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/libri_test.jsonl
UNITS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libri_test_paperfix/unit_records.jsonl
TARGET_MAP=/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl
TARGET_EMBEDDINGS=/public/home/a094f4d10/voice_projects/runs/n019_official/layer9_step8k_test_20261117/target_speaker_mean32_shrink01_843.npz
DURATION_MODEL=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"

for required in \
  "$RECORDS" "$EMBEDDINGS" "$INIT_GENERATOR" \
  "$SOURCE" "$UNITS" "$TARGET_MAP" "$TARGET_EMBEDDINGS" "$DURATION_MODEL" \
  "$VPC_ROOT/libri_test/wav.scp" \
  "$VPC_ROOT/libri_test_enrolls/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/trials" \
  "$VPC_ROOT/libri_test_trials_m/wav.scp" \
  "$VPC_ROOT/libri_test_trials_m/trials"; do
  test -s "$required" || {
    echo "Missing speaker-scale fine-tune input: $required" >&2
    exit 1
  }
done

test "$(sha256sum "$INIT_GENERATOR" | awk '{print $1}')" = "$INIT_SHA"
test "$(wc -l < "$SOURCE")" = 1934
test "$(wc -l < "$UNITS")" = 1934
test "$(wc -l < "$TARGET_MAP")" = 1934

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=2k-step speaker-conditioning amplitude calibration from the formal soup"
echo "train speaker scale=1.5 lr=5e-5 total_batch=16 steps=2000"
echo "records=$RECORDS"
echo "embeddings=$EMBEDDINGS"
echo "init_generator=$INIT_GENERATOR sha256=$INIT_SHA"
echo "train_out=$TRAIN_OUT"
echo "wall=2.5h expected=0.7 worst=2.5 card-hours"

export N019_NPROC=1
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RECORDS="$RECORDS"
export N019_VOCODER_EMBEDDINGS="$EMBEDDINGS"
export N019_VOCODER_OUT="$TRAIN_OUT"
export N019_VOCODER_STEPS=2000
export N019_VOCODER_LR=5e-5
export N019_VOCODER_OPTIMIZER=adamw
export N019_VOCODER_TOTAL_BATCH=16
export N019_VOCODER_BF16=1
export N019_VOCODER_WORKERS=8
export N019_VOCODER_MAX_HOURS=1.5
export N019_VOCODER_CHECKPOINT_INTERVAL=500
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL=500
export N019_VOCODER_KEEP_INTERVAL=10000
export N019_VOCODER_VALIDATION_INTERVAL=500
export N019_VOCODER_SELECTION_POLICY=mel_l1
export N019_VOCODER_EARLY_STOP_MIN_STEPS=2000
export N019_VOCODER_EARLY_STOP_PATIENCE=10
export N019_VOCODER_EARLY_STOP_MIN_DELTA=0.001
export N019_VOCODER_SPEAKER_EMBEDDING_SCALE=1.5
export N019_VOCODER_INIT_GENERATOR="$INIT_GENERATOR"
export N019_VOCODER_INIT_GENERATOR_SHA256="$INIT_SHA"
export N019_SHARED_VOICE_ROOT=/public/home/a094f4d6/voice_projects

bash "$ROOT/scripts/run_vocoder_ddp.sh"

SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
TARGET_EMBEDDING_SHA="$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')"
test "$DURATION_SHA" = "8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"
test "$TARGET_EMBEDDING_SHA" = "5d00633b04e1ab4b70ebb40b657aa36c25f7809c64a5ce0333d1d2d5e14834c4"

for STEP in 1000 2000; do
  VOCODER="$TRAIN_OUT/snapshots/generator_step$(printf '%08d' "$STEP").pt"
  test -s "$VOCODER" || {
    echo "Missing calibrated generator snapshot: $VOCODER" >&2
    exit 1
  }
  VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"
  LABEL="scl15ft${STEP}_20261117"
  OUT="$N019_OFFICIAL_RUNS/speaker_scale15_ft_test_20261117/step_${STEP}"
  SUFFIX="_n019_${LABEL}"

  echo "SPEAKER_SCALE_FT_EVAL_START step=$STEP vocoder_sha256=$VOCODER_SHA out=$OUT"
  mkdir -p "$OUT"

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
  export N019_SPEAKER_EMBEDDING_SCALE=1.5

  bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

  export N019_EVAL_LABEL="$LABEL"
  export N019_EVAL_SYSTEM="DU-pred-nt-speaker-scale15-finetune-$STEP"
  export N019_EVAL_STEPS="$STEP"
  export N019_EVAL_VOCODER="$VOCODER"
  export N019_EVAL_VOC_SHA="$VOCODER_SHA"
  export N019_EVAL_TARGET_EMBEDDINGS="$TARGET_EMBEDDINGS"
  export N019_EVAL_TARGET_EMBEDDING_KEY=target_speaker
  export N019_EVAL_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1
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

  python - "$OUT/eval" "$OUT/wnt_il" "$VOCODER" "$OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

eval_out = Path(sys.argv[1])
wnt_out = Path(sys.argv[2])
vocoder = sys.argv[3]
destination = Path(sys.argv[4])
quality = json.loads((eval_out / "quality_metrics.json").read_text(encoding="utf-8"))
wnt = json.loads((wnt_out / "summary.json").read_text(encoding="utf-8"))
result = {
    "quality": quality["values"],
    "paper_quality": {"WER": 7.41, "UTMOS": 3.63, "WhiSQA": 3.69},
    "wnt_I": float(wnt["attacks"]["I"]["mean_eer_percent"]),
    "wnt_L": float(wnt["attacks"]["L"]["mean_eer_percent"]),
    "paper_wnt_I": 39.9,
    "paper_wnt_L": 42.3,
    "conditioning_scale": 1.5,
    "vocoder": vocoder,
}
destination.write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

  sha256sum \
    "$VOCODER" \
    "$OUT/anonymised/anon.jsonl" \
    "$OUT/verification.json" \
    "$OUT/eval/quality_metrics.json" \
    "$OUT/wnt_il/summary.json" \
    "$OUT/summary.json"
  echo "SPEAKER_SCALE_FT_EVAL_COMPLETE step=$STEP out=$OUT"
done

sha256sum "$TRAIN_OUT/last.pt" "$TRAIN_OUT/meta.json"
echo "N019_SPEAKER_SCALE_FT_COMPLETE out=$TRAIN_OUT"
