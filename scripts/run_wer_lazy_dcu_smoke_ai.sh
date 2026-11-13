#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
DATASET="tmp_wer_smoke_lazy8_n019_ext102k"
MODEL="$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local"
OUT="$N019_OFFICIAL_RUNS/eval/wer_native_dcu_smoke"

test "$(wc -l < "$VPC_ROOT/$DATASET/wav.scp")" = 8
test "$(wc -l < "$VPC_ROOT/$DATASET/text")" = 8
test -f "$MODEL/config.json"
mkdir -p "$OUT"

export PYTHONPATH="$ROOT/vendor/Voice-Privacy-Challenge-2024:$ROOT/src:${PYTHONPATH:-}"
python -u -m n019.wer_eval_hf \
  --vpc-data-root "$VPC_ROOT" \
  --dataset "$DATASET" \
  --model "$MODEL" \
  --device cuda \
  --expected-count 8 \
  --batch-size 8 \
  --out "$OUT/WER.json" \
  2>&1 | tee "$OUT/WER.log"

python - "$OUT/WER.json" <<'PY'
import json
import math
import sys

result = json.load(open(sys.argv[1], encoding="utf-8"))
if result["utterances"] != 8 or result["references"] != 8:
    raise SystemExit(f"Expected 8 utterances, got {result}")
if not math.isfinite(result["wer"]) or not 0.0 <= result["wer"] <= 1.0:
    raise SystemExit(f"Invalid WER: {result['wer']}")
print(json.dumps(result, indent=2, sort_keys=True))
PY

echo "WER_LAZY_DCU_SMOKE_COMPLETE out=$OUT"
