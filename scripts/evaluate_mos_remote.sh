#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SUFFIX="${N019_DATA_SUFFIX:-_n019}"
RUN_NAME="${N019_RUN_NAME:-du_mos}"
DEVICE="${N019_MOS_DEVICE:-cuda}"
LIMIT="${N019_MOS_LIMIT:-0}"
OUT="${N019_MOS_OUT:-$N019_OFFICIAL_RUNS/eval/$RUN_NAME/mos}"
DATA="$N019_OFFICIAL_DATA/vpc/data"
MODELS="$N019_OFFICIAL_MODELS/mos"
ALL_SCP="${N019_MOS_WAV_SCP:-$DATA/libri_test$SUFFIX/wav.scp}"
F_SCP="$DATA/libri_test_trials_f$SUFFIX/wav.scp"
M_SCP="$DATA/libri_test_trials_m$SUFFIX/wav.scp"
UTMOS_CHECKPOINT="$MODELS/UTMOS22-mirror/model.ckpt"
WHISQA_CHECKPOINT="$ROOT/vendor/WhiSQA/checkpoints/single_head_model.pt"

for required in \
  "$ALL_SCP" \
  "$F_SCP" \
  "$M_SCP" \
  "$UTMOS_CHECKPOINT" \
  "$WHISQA_CHECKPOINT" \
  "$ROOT/vendor/UTMOS22-demo/score.py"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing MOS input: $required" >&2
    exit 1
  fi
done

test "$(wc -l < "$ALL_SCP")" = 1934
mkdir -p "$OUT"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "date=$(date -Is)"
  echo "suffix=$SUFFIX"
  echo "wav_scp=$ALL_SCP"
  echo "wav_rows=1934"
  echo "device=$DEVICE"
  echo "limit=$LIMIT"
  echo "out=$OUT"
} | tee "$OUT/launch.txt"

python -u -m n019.eval_mos \
  --backend utmos \
  --wav-scp "$ALL_SCP" \
  --vpc-data-root "$DATA" \
  --code-source "$ROOT/vendor/UTMOS22-demo" \
  --checkpoint "$UTMOS_CHECKPOINT" \
  --device "$DEVICE" \
  --limit "$LIMIT" \
  --out "$OUT/UTMOS.json" \
  2>&1 | tee "$OUT/UTMOS.log"

python -u -m n019.eval_mos \
  --backend whisqa \
  --wav-scp "$ALL_SCP" \
  --vpc-data-root "$DATA" \
  --code-source "$ROOT/vendor/WhiSQA" \
  --checkpoint "$WHISQA_CHECKPOINT" \
  --device "$DEVICE" \
  --limit "$LIMIT" \
  --out "$OUT/WhiSQA.json" \
  2>&1 | tee "$OUT/WhiSQA.log"

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
summary = {}
for name in ("UTMOS", "WhiSQA"):
    data = json.loads((out / f"{name}.json").read_text(encoding="utf-8"))
    summary[name] = {
        "mean": data["mean"],
        "stddev": data["stddev"],
        "count": data["count"],
        "model_sha256": data["model_sha256"],
    }
(out / "summary.json").write_text(
    json.dumps(summary, indent=2) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2))
PY

echo "MOS_EVAL_COMPLETE out=$OUT"
