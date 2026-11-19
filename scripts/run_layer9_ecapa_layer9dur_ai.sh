#!/usr/bin/env bash

set -euo pipefail

ROOT="/public/home/a094f4d10/voice_projects/code/n019_official"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="/public/home/a094f4d10/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
export TMPDIR="/dev/shm/n019_l9e9d_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

LABEL="layer9_ecapa_layer9dur_20261117"
SUFFIX="_n019_${LABEL}"
HYBRID_ROOT="$N019_OFFICIAL_RUNS/layer9_ecapa_hybrid_20261117"
RECORDS="$HYBRID_ROOT/bundle/unit_records.jsonl"
SOURCE_RECORDS="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117/units/unit_records.jsonl"
LAYER9_TRAIN_RECORDS="$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_100_layer9_aligned/unit_records.jsonl"
TARGET_MAP="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117/target_map.jsonl"
SOURCE_ECAPA="$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_100_ecapa_20261117/ecapa_speaker_embeddings.npz"
NT_TARGET="$N019_OFFICIAL_RUNS/du_ecapa_nt_20261117/test_assets/nt_target_843.npz"
ECAPA_TARGET="$N019_OFFICIAL_RUNS/du_ecapa_nt_20261117/test_assets/ecapa_target_843.npz"
DURATION_OUT="$N019_OFFICIAL_RUNS/duration_ecapa_layer9_20261117"
DURATION_MODEL="$DURATION_OUT/best.pt"
VOCODER="$N019_OFFICIAL_RUNS/vocoder_nt_layer9_aligned_pilot_20261116/snapshots/generator_step00020000.pt"
VOCODER_SHA="34f4c46b2e85373585340e0d9b6fc04e72fc9b2d0398edf2181c4b3d233d6b84"
EVAL_OUT="$N019_OFFICIAL_RUNS/eval/${LABEL}"
WNT_OUT="$N019_OFFICIAL_RUNS/eval/${LABEL}_wnt"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc_ai/data"

test "$(wc -l < "$RECORDS")" = 1934
test "$(wc -l < "$LAYER9_TRAIN_RECORDS")" = 33236
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "$VOCODER_SHA"

mkdir -p "$DURATION_OUT"
if [[ ! -s "$DURATION_MODEL" ]]; then
  python -u -m n019.duration \
    --records "$LAYER9_TRAIN_RECORDS" \
    --embeddings "$SOURCE_ECAPA" \
    --speaker-dim 192 \
    --embedding-kind ecapa \
    --epochs 30 \
    --batch-size 32 \
    --workers 4 \
    --device cuda \
    --out "$DURATION_OUT" \
    2>&1 | tee "$DURATION_OUT.log"
fi
test -s "$DURATION_MODEL"

export N019_EVAL_LABEL="$LABEL"
export N019_EVAL_SYSTEM="DU-pred-nt-layer9-ecapa-layer9dur-hybrid"
export N019_EVAL_VPC_DATA="$VPC_ROOT"
export N019_EVAL_VOCODER="$VOCODER"
export N019_EVAL_VOC_SHA="$VOCODER_SHA"
export N019_EVAL_STEPS="20000"
export N019_EVAL_TARGET_EMBEDDINGS="$NT_TARGET"
export N019_EVAL_TARGET_EMBEDDING_KEY="target_speaker"
export N019_EVAL_TARGET_EMBEDDING_MODE="speaker_mean_l2"
export N019_EVAL_DURATION_MODE="ecapa"
export N019_EVAL_DURATION_MODEL="$DURATION_MODEL"
export N019_EVAL_DURATION_EMBEDDINGS="$ECAPA_TARGET"
export N019_EVAL_DURATION_EMBEDDING_KEY="target_speaker"
export N019_EVAL_ANON_OUT="$N019_OFFICIAL_RUNS/${LABEL}/anonymised"
export N019_EVAL_OUT="$EVAL_OUT"

export N019_LIBRI_TEST_SOURCE="$RECORDS"
export N019_LIBRI_TEST_UNITS="$RECORDS"
export N019_LIBRI_TEST_TARGET_MAP="$TARGET_MAP"
export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$NT_TARGET"
export N019_LIBRI_TEST_TARGET_EMBEDDING_KEY="target_speaker"
export N019_LIBRI_TEST_TARGET_EMBEDDING_MODE="speaker_mean_l2"
export N019_LIBRI_TEST_DURATION_MODE="ecapa"
export N019_LIBRI_TEST_DURATION_MODEL="$DURATION_MODEL"
export N019_LIBRI_TEST_DURATION_EMBEDDINGS="$ECAPA_TARGET"
export N019_LIBRI_TEST_DURATION_EMBEDDING_KEY="target_speaker"
export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA="$(
  sha256sum "$RECORDS" | awk '{print $1}'
)"
export N019_LIBRI_TEST_EXPECTED_DURATION_SHA="$(
  sha256sum "$DURATION_MODEL" | awk '{print $1}'
)"

bash "$ROOT/scripts/run_full_eval_param_ai.sh"

export N019_VPC_DATA="$VPC_ROOT"
export N019_DATA_SUFFIX="$SUFFIX"
export N019_RUN_NAME="${LABEL}_wnt"
export N019_WNT_ATTACKS="I L"
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$WNT_OUT"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"

python "$ROOT/scripts/assemble_du_ecapa_nt_summary.py" \
  --quality "$EVAL_OUT/quality_metrics.json" \
  --wnt-summary "$WNT_OUT/summary.json" \
  --out "$EVAL_OUT/layer9_ecapa_layer9dur_summary.json" \
  --system "DU-pred-nt-layer9-ecapa-layer9dur-hybrid" \
  --paper-wer 7.41 \
  --paper-utmos 3.63 \
  --paper-whisqa 3.69 \
  --paper-wnt-i 39.9 \
  --paper-wnt-l 42.3

sha256sum \
  "$DURATION_MODEL" \
  "$RECORDS" \
  "$VOCODER" \
  "$NT_TARGET" \
  "$ECAPA_TARGET" \
  "$EVAL_OUT/quality_metrics.json" \
  "$EVAL_OUT/layer9_ecapa_layer9dur_summary.json" \
  "$WNT_OUT/summary.json"

echo "N019_LAYER9_ECAPA_LAYER9DUR_COMPLETE out=$EVAL_OUT"
