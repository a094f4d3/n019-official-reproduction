#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
VOICE_ROOT=/public/home/a094f4d10/voice_projects
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="$VOICE_ROOT"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

WORK=/dev/shm/n019_softcap075_recovery_${SLURM_JOB_ID:-manual}
OUT="$VOICE_ROOT/runs/n019_official/softcap075_recovery_20261119"
ANON_OUT="$OUT/anonymised"
WNT_OUT="$OUT/wnt_l"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
SUFFIX=_n019_softcap075_recovery_20261119
mkdir -p "$WORK" "$OUT"
export TMPDIR="$WORK"

SOURCE=/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/libri_test.jsonl
UNITS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libri_test_paperfix/unit_records.jsonl
TARGET_MAP=/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl
TARGET_EMBEDDINGS=/public/home/a094f4d10/voice_projects/data/n019_official/processed/embeddings/nt_ecapa_residual_test_20261117/residual_0p5.npz
DURATION_MODEL=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt
VOCODER=/public/home/a094f4d10/voice_projects/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt

for required in \
  "$SOURCE" "$UNITS" "$TARGET_MAP" "$TARGET_EMBEDDINGS" \
  "$DURATION_MODEL" "$VOCODER" \
  "$VPC_ROOT/libri_test/wav.scp" \
  "$VPC_ROOT/libri_test_enrolls/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/trials" \
  "$VPC_ROOT/libri_test_trials_m/wav.scp" \
  "$VPC_ROOT/libri_test_trials_m/trials"; do
  test -s "$required" || {
    echo "Missing recovery input: $required" >&2
    exit 1
  }
done

test "$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')" = \
  "7a015304bebdcd12bcb4deda5792ea1941159650eff4c97367716b0748e690ef"
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = \
  "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = \
  "8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"
SOURCE_SHA="$(sha256sum "$SOURCE" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"

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
export N019_LIBRI_TEST_ANON_OUT="$ANON_OUT"
export N019_LIBRI_TEST_SUFFIX="$SUFFIX"
export N019_LIBRI_TEST_VERIFY="$OUT/verification.json"
export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA="$SOURCE_SHA"
export N019_LIBRI_TEST_EXPECTED_DURATION_SHA="$DURATION_SHA"
export N019_LIBRI_TEST_EXPECTED_VOCODER_SHA="$VOCODER_SHA"
export N019_SPEAKER_EMBEDDING_SCALE=1.0
export N019_DURATION_EXTRAPOLATION=0.5
export N019_DURATION_PRESERVE_TOTAL=1
export N019_DURATION_SOFT_CAP_FRAMES=0.75
bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

ANON_SHA="$(sha256sum "$ANON_OUT/anon.jsonl" | awk '{print $1}')"
if [[ "$ANON_SHA" != "eac6f4e73936c24b2e03b744f522de30b9ad25d1a012a36fcef4537ae7f22868" ]]; then
  echo "Soft-cap 0.75 audio drifted: $ANON_SHA" >&2
  exit 1
fi

export N019_DATA_SUFFIX="$SUFFIX"
export N019_VPC_DATA="$VPC_ROOT"
export N019_WNT_BASE_VPC_DATA="$VPC_ROOT"
export N019_WNT_ATTACKS="L"
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$WNT_OUT"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"

python - "$OUT" "$ANON_SHA" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
anon_sha = sys.argv[2]
wnt = json.loads((out / "wnt_l" / "summary.json").read_text(
    encoding="utf-8"
))
result = {
    "duration_soft_cap_frames": 0.75,
    "duration_extrapolation": 0.5,
    "preserve_predicted_total": True,
    "anon_jsonl_sha256": anon_sha,
    "quality_reused_after_deterministic_audio_hash_match": {
        "WER": 7.705039666685692,
        "UTMOS": 3.6297726352557524,
        "WhiSQA": 3.6223786648636396,
    },
    "wnt_I_reference_female": 40.14712572097778,
    "wnt_I_reference_male": 42.78298169374466,
    "wnt_I_reference_mean": 41.46505370736122,
    "wnt_L": wnt["attacks"]["L"],
}
(out / "summary.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum "$OUT/summary.json" "$WNT_OUT/summary.json" "$ANON_OUT/anon.jsonl"
echo "N019_SOFTCAP075_RECOVERY_COMPLETE"
