#!/bin/bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-/public/home/a094f4d10/voice_projects/code/n019_official}"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="/public/home/a094f4d10/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

BUNDLE="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117"
RECORDS="$BUNDLE/units/unit_records.jsonl"
TARGET_MAP="$BUNDLE/target_map.jsonl"
TARGET_EMBEDDINGS="$BUNDLE/assets/target_nt_utterance.npz"
VOCODER="$BUNDLE/assets/generator_soup2.pt"
DURATION="$BUNDLE/assets/duration_nt_main.pt"

for required in \
  "$RECORDS" \
  "$TARGET_MAP" \
  "$TARGET_EMBEDDINGS" \
  "$VOCODER" \
  "$DURATION"; do
  test -s "$required" || {
    echo "Missing DU-nt-nt bundle input: $required" >&2
    exit 1
  }
done
test "$(wc -l < "$RECORDS")" = 1934
test "$(find "$BUNDLE/units/codes" -maxdepth 1 -type f -name '*.npy' | wc -l)" = 1934

SOURCE_SHA="$(sha256sum "$RECORDS" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION" | awk '{print $1}')"

export N019_LIBRI_TEST_SOURCE="$RECORDS"
export N019_LIBRI_TEST_UNITS="$RECORDS"
export N019_LIBRI_TEST_TARGET_MAP="$TARGET_MAP"
export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA="$SOURCE_SHA"
export N019_LIBRI_TEST_EXPECTED_DURATION_SHA="$DURATION_SHA"

export N019_EVAL_LABEL="du_nt_nt_utt_20261117"
export N019_EVAL_SYSTEM="DU-nt-nt-target-utterance"
export N019_EVAL_VPC_DATA="$N019_OFFICIAL_DATA/vpc_ai/data"
export N019_EVAL_VOCODER="$VOCODER"
export N019_EVAL_VOC_SHA="$VOCODER_SHA"
export N019_EVAL_STEPS="96000"
export N019_EVAL_TARGET_EMBEDDINGS="$TARGET_EMBEDDINGS"
export N019_EVAL_TARGET_EMBEDDING_KEY="target_id"
export N019_EVAL_TARGET_EMBEDDING_MODE="utterance"
export N019_EVAL_DURATION_MODE="nt"
export N019_EVAL_DURATION_MODEL="$DURATION"
export N019_EVAL_DURATION_EMBEDDINGS="$TARGET_EMBEDDINGS"
export N019_EVAL_DURATION_EMBEDDING_KEY="target_id"
export N019_EVAL_ANON_OUT="$N019_OFFICIAL_DATA/anonymised/libri_test/DU-nt-nt-utt-20261117"
export N019_EVAL_OUT="$N019_OFFICIAL_RUNS/eval/du_nt_nt_utt_20261117"
export N019_WNT_OUT="$N019_OFFICIAL_RUNS/eval/du_nt_nt_utt_20261117_wnt"
unset N019_LIBRI_TEST_EXPECTED_VOCODER_SHA

if [[ "$(id -u)" == "0" ]]; then
  owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
  trap 'chown -R "$owner" "$N019_EVAL_ANON_OUT" "$N019_EVAL_OUT" "$N019_WNT_OUT" 2>/dev/null || true' EXIT
fi

bash "$ROOT/scripts/run_full_eval_param_ai.sh"

export N019_VPC_DATA="$N019_EVAL_VPC_DATA"
export N019_DATA_SUFFIX="_n019_du_nt_nt_utt_20261117"
export N019_RUN_NAME="du_nt_nt_utt_20261117_wnt"
export N019_WNT_ATTACKS="I L"
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"
