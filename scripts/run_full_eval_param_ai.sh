#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

LABEL="${N019_EVAL_LABEL:?Set N019_EVAL_LABEL (e.g. ft14k_long20k)}"
SYSTEM="${N019_EVAL_SYSTEM:-DU-pred-nt-$LABEL}"
VOCAB="${N019_EVAL_VOCODER:?Set N019_EVAL_VOCODER}"
EXPECTED_VOCAB_SHA="${N019_EVAL_VOC_SHA:?Set N019_EVAL_VOC_SHA}"
STEPS="${N019_EVAL_STEPS:-0}"
TARGET_EMBEDDINGS="${N019_EVAL_TARGET_EMBEDDINGS:-$N019_OFFICIAL_DATA/processed/embeddings/libri_test_target_nt_speaker_mean_l2_paperfix/nt_target_speaker_embeddings.npz}"
TARGET_EMBEDDING_KEY="${N019_EVAL_TARGET_EMBEDDING_KEY:-target_speaker}"
TARGET_EMBEDDING_MODE="${N019_EVAL_TARGET_EMBEDDING_MODE:-speaker_mean_l2}"
DURATION_MODE="${N019_EVAL_DURATION_MODE:-pred}"
DURATION_MODEL="${N019_EVAL_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_pred_paperfix/best.pt}"
DURATION_EMBEDDINGS="${N019_EVAL_DURATION_EMBEDDINGS:-}"
DURATION_EMBEDDING_KEY="${N019_EVAL_DURATION_EMBEDDING_KEY:-target_id}"

SUFFIX="_n019_${LABEL}"
RUN_NAME="du_pred_nt_${LABEL}"
ANON="${N019_EVAL_ANON_OUT:-$N019_OFFICIAL_DATA/anonymised/libri_test/DU-pred-nt-${LABEL}}"
VPC_ROOT="${N019_EVAL_VPC_DATA:-$N019_OFFICIAL_DATA/vpc/data}"
OUT="${N019_EVAL_OUT:-$N019_OFFICIAL_RUNS/eval/$RUN_NAME}"
WHISPER_SMALL_PATH="$N019_VOICE_ROOT/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"
export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"

for required in \
  "$VOCAB" \
  "$DURATION_MODEL" \
  "$TARGET_EMBEDDINGS" \
  "$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt" \
  "$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt" \
  "$WHISPER_SMALL_PATH/config.json" \
  "$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local/config.json" \
  "$ROOT/vendor/UTMOS22-demo/score.py" \
  "$ROOT/vendor/WhiSQA/models/whisper_ni_predictors.py"; do
  test -f "$required" || {
    echo "Missing evaluation input: $required" >&2
    exit 1
  }
done
if [[ "$DURATION_MODE" == "nt" || "$DURATION_MODE" == "ecapa" ]]; then
  test -f "$DURATION_EMBEDDINGS" || {
    echo "Missing duration embeddings: $DURATION_EMBEDDINGS" >&2
    exit 1
  }
fi
test "$(sha256sum "$VOCAB" | awk '{print $1}')" = "$EXPECTED_VOCAB_SHA"

export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$TARGET_EMBEDDINGS"
export N019_LIBRI_TEST_TARGET_EMBEDDING_KEY="$TARGET_EMBEDDING_KEY"
export N019_LIBRI_TEST_TARGET_EMBEDDING_MODE="$TARGET_EMBEDDING_MODE"
export N019_LIBRI_TEST_VPC_DATA="$VPC_ROOT"
export N019_LIBRI_TEST_DURATION_MODE="$DURATION_MODE"
export N019_LIBRI_TEST_DURATION_MODEL="$DURATION_MODEL"
export N019_LIBRI_TEST_DURATION_EMBEDDINGS="$DURATION_EMBEDDINGS"
export N019_LIBRI_TEST_DURATION_EMBEDDING_KEY="$DURATION_EMBEDDING_KEY"
export N019_LIBRI_TEST_VOCODER="$VOCAB"
export N019_LIBRI_TEST_EXPECTED_VOCODER_SHA="$EXPECTED_VOCAB_SHA"
export N019_LIBRI_TEST_ANON_OUT="$ANON"
export N019_LIBRI_TEST_SUFFIX="$SUFFIX"
export N019_LIBRI_TEST_VERIFY="$ROOT/audit/verify_libri_test_${LABEL}.json"

if [[ -f "$ANON/anon.jsonl" ]] &&
   [[ "$(wc -l < "$ANON/anon.jsonl")" == "1934" ]] &&
   [[ "$(find "$ANON" -maxdepth 1 -type f -name '*.wav' | wc -l)" == "1934" ]] &&
   [[ -f "$VPC_ROOT/libri_test$SUFFIX/wav.scp" ]] &&
   [[ "$(wc -l < "$VPC_ROOT/libri_test$SUFFIX/wav.scp")" == "1934" ]]; then
  echo "REUSE_COMPLETE_ANON_AND_VPC label=$LABEL"
else
  bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"
fi

WAV_SCP="$VPC_ROOT/libri_test$SUFFIX/wav.scp"
test "$(wc -l < "$WAV_SCP")" = 1934
test "$(wc -l < "$VPC_ROOT/libri_test_enrolls$SUFFIX/wav.scp")" = 438
test "$(wc -l < "$VPC_ROOT/libri_test_trials_f$SUFFIX/wav.scp")" = 734
test "$(wc -l < "$VPC_ROOT/libri_test_trials_f$SUFFIX/trials")" = 11744
test "$(wc -l < "$VPC_ROOT/libri_test_trials_m$SUFFIX/wav.scp")" = 762
test "$(wc -l < "$VPC_ROOT/libri_test_trials_m$SUFFIX/trials")" = 9906

ASR_DATASET="libri_test_asr$SUFFIX"
python - "$ROOT/vendor/Voice-Privacy-Challenge-2024" "$VPC_ROOT" \
  "$ASR_DATASET" "$SUFFIX" <<'PY'
import sys
from pathlib import Path

vendor, vpc_root, output_name, suffix = sys.argv[1:]
sys.path.insert(0, vendor)
from utils.prepare_results_in_kaldi_format import combine_asr_data

vpc_root = Path(vpc_root)
combine_asr_data(
    [
        vpc_root / f"libri_test_trials_f{suffix}",
        vpc_root / f"libri_test_trials_m{suffix}",
    ],
    vpc_root / output_name,
)
PY
test "$(wc -l < "$VPC_ROOT/$ASR_DATASET/wav.scp")" = 1496
test "$(wc -l < "$VPC_ROOT/$ASR_DATASET/text")" = 1496

mkdir -p "$OUT/mos"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "date=$(date -Is)"
  echo "scope=full_quality_eval label=$LABEL"
  echo "vocoder=$VOCAB"
  echo "vocoder_sha256=$EXPECTED_VOCAB_SHA"
  echo "anon=$ANON"
  echo "out=$OUT"
} | tee "$OUT/launch.txt"

if [[ -f "$OUT/WER.json" ]]; then
  echo "REUSE_COMPLETE_WER"
else
  python -u -m n019.wer_eval_vpc \
    --vpc-data-root "$VPC_ROOT" \
    --dataset "$ASR_DATASET" \
    --model "$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local" \
    --device cuda \
    --expected-count 1496 \
    --out "$OUT/WER.json" \
    2>&1 | tee "$OUT/WER.log"
fi

if [[ ! -f "$OUT/mos/UTMOS.json" ]]; then
  PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/" \
    python -u -m n019.eval_mos \
    --backend utmos \
    --wav-scp "$WAV_SCP" \
    --vpc-data-root "$VPC_ROOT" \
    --code-source "$ROOT/vendor/UTMOS22-demo" \
    --checkpoint "$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt" \
    --device cuda \
    --out "$OUT/mos/UTMOS.json" \
    2>&1 | tee "$OUT/mos/UTMOS.log"
fi

if [[ ! -f "$OUT/mos/WhiSQA.json" ]]; then
  PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/" \
    python -u -m n019.eval_mos \
    --backend whisqa \
    --wav-scp "$WAV_SCP" \
    --vpc-data-root "$VPC_ROOT" \
    --code-source "$ROOT/vendor/WhiSQA" \
    --checkpoint "$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt" \
    --device cuda \
    --out "$OUT/mos/WhiSQA.json" \
    2>&1 | tee "$OUT/mos/WhiSQA.log"
fi

python - "$OUT" "$SYSTEM" "$STEPS" "$EXPECTED_VOCAB_SHA" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
system, steps, vocoder_sha = sys.argv[2], int(sys.argv[3]), sys.argv[4]
wer = json.loads((out / "WER.json").read_text(encoding="utf-8"))
utmos = json.loads((out / "mos" / "UTMOS.json").read_text(encoding="utf-8"))
whisqa = json.loads((out / "mos" / "WhiSQA.json").read_text(encoding="utf-8"))
if int(wer["utterances"]) != 1496:
    raise SystemExit(f"Expected 1496 WER utterances, got {wer['utterances']}")
if int(utmos["count"]) != 1934 or int(whisqa["count"]) != 1934:
    raise SystemExit("Expected 1934 UTMOS and WhiSQA utterances")

paper = {"WER": 7.41, "UTMOS": 3.63, "WhiSQA": 3.69}
values = {
    "WER": float(wer["wer_percent"]),
    "UTMOS": float(utmos["mean"]),
    "WhiSQA": float(whisqa["mean"]),
}
comparison = {}
for name in ("WER", "UTMOS", "WhiSQA"):
    absolute = values[name] - paper[name]
    comparison[name] = {
        "paper": paper[name],
        "reproduced": values[name],
        "absolute_difference": absolute,
        "relative_difference_percent": absolute / paper[name] * 100.0,
    }
summary = {
    "system": system,
    "vocoder_steps": steps,
    "vocoder_sha256": vocoder_sha,
    "values": values,
    "comparison": comparison,
}
(out / "quality_metrics.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2, sort_keys=True))
PY

sha256sum \
  "$VOCAB" \
  "$ANON/anon.jsonl" \
  "$OUT/WER.json" \
  "$OUT/mos/UTMOS.json" \
  "$OUT/mos/WhiSQA.json" \
  "$OUT/quality_metrics.json"
echo "N019_FULL_QUALITY_COMPLETE label=$LABEL out=$OUT"
