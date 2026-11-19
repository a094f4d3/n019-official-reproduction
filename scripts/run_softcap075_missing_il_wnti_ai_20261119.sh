#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
VOICE_ROOT=/public/home/a094f4d10/voice_projects
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="$VOICE_ROOT"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

WORK="/dev/shm/n019_softcap075_missing_$(date +%s)_$$"
PUBLIC_OUT="$N019_OFFICIAL_RUNS/softcap075_missing_il_wnti_20261119"
BUNDLE="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117"
RECORDS="$BUNDLE/units/unit_records.jsonl"
TARGET_MAP="$BUNDLE/target_map.jsonl"
VOCODER="$BUNDLE/assets/generator_soup2.pt"
DURATION="$BUNDLE/assets/duration_pred_paperfix_best.pt"
TARGET_EMBEDDINGS="$N019_OFFICIAL_DATA/processed/embeddings/nt_ecapa_residual_test_20261117/residual_0p5.npz"
VPC_BASE="$N019_OFFICIAL_DATA/vpc_ai/data"
SUFFIX=_n019_softcap075_recovery_20261119

mkdir -p "$WORK/tmp" "$PUBLIC_OUT"
export TMPDIR="$WORK/tmp"
cp -a "$VPC_BASE" "$WORK/vpc"

for required in \
  "$RECORDS" "$TARGET_MAP" "$VOCODER" "$DURATION" \
  "$TARGET_EMBEDDINGS" "$WORK/vpc/libri_test/wav.scp" \
  "$WORK/vpc/libri_test_enrolls/wav.scp" \
  "$WORK/vpc/libri_test_trials_f/wav.scp" \
  "$WORK/vpc/libri_test_trials_f/trials" \
  "$WORK/vpc/libri_test_trials_m/wav.scp" \
  "$WORK/vpc/libri_test_trials_m/trials"; do
  test -s "$required" || {
    echo "Missing soft-cap 0.75 input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$RECORDS")" = 1934
test "$(wc -l < "$TARGET_MAP")" = 1934
test "$(find "$BUNDLE/units/codes" -maxdepth 1 -type f -name '*.npy' | wc -l)" = 1934
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = \
  "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
test "$(sha256sum "$DURATION" | awk '{print $1}')" = \
  "8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"
test "$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')" = \
  "7a015304bebdcd12bcb4deda5792ea1941159650eff4c97367716b0748e690ef"

SOURCE_SHA="$(sha256sum "$RECORDS" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"

echo "ai_task=${MARSV2_TASK_ID:-manual} host=$(hostname) date=$(date -Is)"
echo "purpose=softcap075 missing E-VPC I/L and W-NT I"
echo "work=$WORK public_out=$PUBLIC_OUT"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

export N019_LIBRI_TEST_SOURCE="$RECORDS"
export N019_LIBRI_TEST_UNITS="$RECORDS"
export N019_LIBRI_TEST_TARGET_MAP="$TARGET_MAP"
export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$TARGET_EMBEDDINGS"
export N019_LIBRI_TEST_TARGET_EMBEDDING_KEY=target_speaker
export N019_LIBRI_TEST_TARGET_EMBEDDING_MODE=speaker_mean_l2
export N019_LIBRI_TEST_DURATION_MODE=pred
export N019_LIBRI_TEST_DURATION_MODEL="$DURATION"
export N019_LIBRI_TEST_VOCODER="$VOCODER"
export N019_LIBRI_TEST_VPC_DATA="$WORK/vpc"
export N019_LIBRI_TEST_ANON_OUT="$WORK/anonymised"
export N019_LIBRI_TEST_SUFFIX="$SUFFIX"
export N019_LIBRI_TEST_VERIFY="$WORK/verification.json"
export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA="$SOURCE_SHA"
export N019_LIBRI_TEST_EXPECTED_DURATION_SHA="$DURATION_SHA"
export N019_LIBRI_TEST_EXPECTED_VOCODER_SHA="$VOCODER_SHA"
export N019_SPEAKER_EMBEDDING_SCALE=1.0
export N019_DURATION_EXTRAPOLATION=0.5
export N019_DURATION_PRESERVE_TOTAL=1
export N019_DURATION_SOFT_CAP_FRAMES=0.75
bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

export N019_VPC_DATA="$WORK/vpc"
export N019_WNT_BASE_VPC_DATA="$WORK/vpc"
export N019_DATA_SUFFIX="$SUFFIX"
export N019_WNT_ATTACKS=I
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$WORK/wnt_i"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"

export N019_EVPC_OUT="$WORK/evpc"
export N019_EVPC_CONFIG="$ROOT/configs/eval_paper_test_only_privacy.yaml"
bash "$ROOT/scripts/evaluate_evpc_pre_remote.sh"

python - "$WORK" "$PUBLIC_OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

work = Path(sys.argv[1])
evpc = json.loads((work / "evpc" / "evpc_metrics.json").read_text())
wnt = json.loads((work / "wnt_i" / "summary.json").read_text())
result = {
    "condition": "residual0.5_duration0.5_softcap0.75",
    "duration_soft_cap_frames": 0.75,
    "duration_extrapolation": 0.5,
    "preserve_predicted_total": True,
    "E_VPC_I": evpc["paper_conditions"]["I"]["mean_eer_percent"],
    "E_VPC_L": evpc["paper_conditions"]["L"]["mean_eer_percent"],
    "W_NT_I": wnt["attacks"]["I"]["mean_eer_percent"],
    "known": {
        "WER": 7.705039666685692,
        "UTMOS": 3.6297727518762155,
        "WhiSQA": 3.622378650994927,
        "W_NT_L": 41.61337688565254,
    },
    "paper": {
        "E_VPC_I": 47.2,
        "E_VPC_L": 47.9,
        "W_NT_I": 39.9,
        "W_NT_L": 42.3,
        "WER": 7.41,
        "UTMOS": 3.63,
        "WhiSQA": 3.69,
    },
}
Path(sys.argv[2]).write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

cp "$WORK/evpc/evpc_metrics.json" "$PUBLIC_OUT/evpc_metrics.json"
cp "$WORK/wnt_i/summary.json" "$PUBLIC_OUT/wnt_i_summary.json"
cp "$WORK/verification.json" "$PUBLIC_OUT/verification.json"
cp "$WORK/anonymised/anon.jsonl" "$PUBLIC_OUT/anon.jsonl"
sha256sum \
  "$PUBLIC_OUT/summary.json" \
  "$PUBLIC_OUT/evpc_metrics.json" \
  "$PUBLIC_OUT/wnt_i_summary.json" \
  "$PUBLIC_OUT/verification.json" \
  "$PUBLIC_OUT/anon.jsonl" > "$PUBLIC_OUT/SHA256SUMS.txt"

# AI containers run as root. Restore ownership for all newly written outputs.
chown -R 666505:666505 "$PUBLIC_OUT"
echo "N019_SOFTCAP075_MISSING_IL_WNTI_COMPLETE work=$WORK out=$PUBLIC_OUT"
