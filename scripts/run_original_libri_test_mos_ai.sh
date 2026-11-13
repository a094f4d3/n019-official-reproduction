#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
WAV_SCP="$VPC_ROOT/libri_test/wav.scp"
OUT="$N019_OFFICIAL_RUNS/eval/original_libri_test_mos"
WHISPER_SMALL_PATH="$N019_VOICE_ROOT/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"

for required in \
  "$WAV_SCP" \
  "$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt" \
  "$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt" \
  "$WHISPER_SMALL_PATH/config.json" \
  "$ROOT/vendor/UTMOS22-demo/score.py" \
  "$ROOT/vendor/WhiSQA/models/whisper_ni_predictors.py"; do
  test -f "$required" || {
    echo "Missing original-MOS input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$WAV_SCP")" = 1934
mkdir -p "$OUT"
export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"

{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "date=$(date -Is)"
  echo "scope=original_libri_test_mos"
  echo "wav_scp=$WAV_SCP"
  echo "out=$OUT"
} | tee "$OUT/launch.txt"

if [[ ! -f "$OUT/UTMOS.json" ]]; then
  PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/" \
    python -u -m n019.eval_mos \
      --backend utmos \
      --wav-scp "$WAV_SCP" \
      --vpc-data-root "$VPC_ROOT" \
      --code-source "$ROOT/vendor/UTMOS22-demo" \
      --checkpoint "$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt" \
      --device cuda \
      --out "$OUT/UTMOS.json" \
      2>&1 | tee "$OUT/UTMOS.log"
fi

if [[ ! -f "$OUT/WhiSQA.json" ]]; then
  PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/" \
    python -u -m n019.eval_mos \
      --backend whisqa \
      --wav-scp "$WAV_SCP" \
      --vpc-data-root "$VPC_ROOT" \
      --code-source "$ROOT/vendor/WhiSQA" \
      --checkpoint "$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt" \
      --device cuda \
      --out "$OUT/WhiSQA.json" \
      2>&1 | tee "$OUT/WhiSQA.log"
fi

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
utmos = json.loads((out / "UTMOS.json").read_text(encoding="utf-8"))
whisqa = json.loads((out / "WhiSQA.json").read_text(encoding="utf-8"))
if int(utmos["count"]) != 1934 or int(whisqa["count"]) != 1934:
    raise SystemExit("Expected 1,934 UTMOS and WhiSQA utterances")
summary = {
    "system": "Original-libri_test",
    "count": 1934,
    "values": {
        "UTMOS": float(utmos["mean"]),
        "WhiSQA": float(whisqa["mean"]),
    },
    "paper": {
        "UTMOS": 4.11,
        "WhiSQA": 4.08,
    },
}
summary["comparison"] = {
    metric: summary["values"][metric] - summary["paper"][metric]
    for metric in ("UTMOS", "WhiSQA")
}
(out / "summary.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2, sort_keys=True))
PY

sha256sum \
  "$OUT/UTMOS.json" \
  "$OUT/WhiSQA.json" \
  "$OUT/summary.json"
echo "N019_ORIGINAL_LIBRI_TEST_MOS_COMPLETE out=$OUT"
