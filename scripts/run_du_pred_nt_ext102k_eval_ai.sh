#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SUFFIX="_n019_ext102k"
RUN_NAME="du_pred_nt_ext102k"
VOCAB="$N019_OFFICIAL_RUNS/audit/vocoder_checkpoint_cpu_20261106/checkpoints/paperfix_ext_best_step102000.pt"
EXPECTED_VOCAB_SHA=62eb5908aae998f50eed1456a8f6a8f606a88c07627c1d92517f0d072c9ff151
ANON="$N019_OFFICIAL_DATA/anonymised/libri_test/DU-pred-nt-ext102k"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
OUT="$N019_OFFICIAL_RUNS/eval/$RUN_NAME"
WHISPER_SMALL_PATH="$N019_VOICE_ROOT/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d"
export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"

for required in \
  "$VOCAB" \
  "$N019_OFFICIAL_RUNS/duration_pred_paperfix/best.pt" \
  "$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt" \
  "$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt" \
  "$WHISPER_SMALL_PATH/config.json" \
  "$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local/config.json" \
  "$ROOT/vendor/UTMOS22-demo/score.py" \
  "$ROOT/vendor/WhiSQA/models/whisper_ni_predictors.py"; do
  test -f "$required" || {
    echo "Missing ext102k evaluation input: $required" >&2
    exit 1
  }
done
test "$(sha256sum "$VOCAB" | awk '{print $1}')" = "$EXPECTED_VOCAB_SHA"

export N019_LIBRI_TEST_VOCODER="$VOCAB"
export N019_LIBRI_TEST_EXPECTED_VOCODER_SHA="$EXPECTED_VOCAB_SHA"
export N019_LIBRI_TEST_ANON_OUT="$ANON"
export N019_LIBRI_TEST_SUFFIX="$SUFFIX"
export N019_LIBRI_TEST_VERIFY="$ROOT/audit/verify_libri_test_du_pred_nt_ext102k.json"
if [[ -f "$ANON/anon.jsonl" ]] &&
   [[ "$(wc -l < "$ANON/anon.jsonl")" == "1934" ]] &&
   [[ "$(find "$ANON" -maxdepth 1 -type f -name '*.wav' | wc -l)" == "1934" ]] &&
   [[ -f "$VPC_ROOT/libri_test$SUFFIX/wav.scp" ]] &&
   [[ "$(wc -l < "$VPC_ROOT/libri_test$SUFFIX/wav.scp")" == "1934" ]] &&
   [[ -f "$VPC_ROOT/libri_test_enrolls$SUFFIX/wav.scp" ]] &&
   [[ "$(wc -l < "$VPC_ROOT/libri_test_enrolls$SUFFIX/wav.scp")" == "438" ]] &&
   [[ -f "$VPC_ROOT/libri_test_trials_f$SUFFIX/trials" ]] &&
   [[ "$(wc -l < "$VPC_ROOT/libri_test_trials_f$SUFFIX/trials")" == "11744" ]] &&
   [[ -f "$VPC_ROOT/libri_test_trials_m$SUFFIX/trials" ]] &&
   [[ "$(wc -l < "$VPC_ROOT/libri_test_trials_m$SUFFIX/trials")" == "9906" ]]; then
  echo "REUSE_COMPLETE_EXT102K_ANON_AND_VPC"
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
  echo "scope=du_pred_nt_ext102k_full_quality_eval"
  echo "vocoder=$VOCAB"
  echo "vocoder_sha256=$EXPECTED_VOCAB_SHA"
  echo "anon=$ANON"
  echo "out=$OUT"
} | tee "$OUT/launch.txt"

python -u -m n019.wer_eval_vpc \
  --vpc-data-root "$VPC_ROOT" \
  --dataset "$ASR_DATASET" \
  --model "$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local" \
  --device cuda \
  --expected-count 1496 \
  --out "$OUT/WER.json" \
  2>&1 | tee "$OUT/WER.log"

python -u -m n019.eval_mos \
  --backend utmos \
  --wav-scp "$WAV_SCP" \
  --vpc-data-root "$VPC_ROOT" \
  --code-source "$ROOT/vendor/UTMOS22-demo" \
  --checkpoint "$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt" \
  --device cuda \
  --out "$OUT/mos/UTMOS.json" \
  2>&1 | tee "$OUT/mos/UTMOS.log"

python -u -m n019.eval_mos \
  --backend whisqa \
  --wav-scp "$WAV_SCP" \
  --vpc-data-root "$VPC_ROOT" \
  --code-source "$ROOT/vendor/WhiSQA" \
  --checkpoint "$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt" \
  --device cuda \
  --out "$OUT/mos/WhiSQA.json" \
  2>&1 | tee "$OUT/mos/WhiSQA.log"

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
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
    "system": "DU-pred-nt-ext102k",
    "vocoder_steps": 102000,
    "vocoder_sha256": "62eb5908aae998f50eed1456a8f6a8f606a88c07627c1d92517f0d072c9ff151",
    "values": values,
    "comparison": comparison,
}
(out / "quality_metrics.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2, sort_keys=True))
PY

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
chown -R "$owner" "$OUT" "$ANON" \
  "$VPC_ROOT/libri_test$SUFFIX" \
  "$VPC_ROOT/libri_test_enrolls$SUFFIX" \
  "$VPC_ROOT/libri_test_trials_f$SUFFIX" \
  "$VPC_ROOT/libri_test_trials_m$SUFFIX"
sha256sum \
  "$VOCAB" \
  "$ANON/anon.jsonl" \
  "$ANON/run_meta.json" \
  "$OUT/WER.json" \
  "$OUT/mos/UTMOS.json" \
  "$OUT/mos/WhiSQA.json" \
  "$OUT/quality_metrics.json"
echo "DU_PRED_NT_EXT102K_FULL_QUALITY_COMPLETE out=$OUT"
