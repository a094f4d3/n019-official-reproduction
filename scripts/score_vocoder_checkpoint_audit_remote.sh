#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

AUDIT="${N019_CHECKPOINT_AUDIT_OUT:-$N019_OFFICIAL_RUNS/audit/vocoder_checkpoint_cpu_20261106}"
DEVICE="${N019_CHECKPOINT_AUDIT_DEVICE:-cuda}"
SAMPLE_COUNT="${N019_CHECKPOINT_AUDIT_SAMPLES:-25}"
OWNER="$(stat -c '%u:%g' "$N019_OFFICIAL_RUNS")"

MODELS=(
  "paperfix_best_step4000"
  "main_best_step76000"
)
MOS_MODELS="$N019_OFFICIAL_MODELS/mos"
UTMOS_CHECKPOINT="$MOS_MODELS/UTMOS22-mirror/model.ckpt"
WHISQA_CHECKPOINT="$MOS_MODELS/WhiSQA_single_head.pt"
WHISPER_SMALL_PATH="${N019_WHISPER_SMALL_PATH:-$HF_HOME/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d}"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"

for required in \
  "$UTMOS_CHECKPOINT" \
  "$WHISQA_CHECKPOINT" \
  "$WHISPER_SMALL_PATH/config.json" \
  "$ROOT/vendor/UTMOS22-demo/score.py" \
  "$ROOT/vendor/WhiSQA/models/whisper_ni_predictors.py"; do
  test -f "$required" || {
    echo "Missing checkpoint-audit MOS input: $required" >&2
    exit 1
  }
done

export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"
export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"

for name in "${MODELS[@]}"; do
  model_out="$AUDIT/$name"
  test -f "$model_out/wav.scp" || {
    echo "Missing generated wav.scp: $model_out/wav.scp" >&2
    exit 1
  }
  test "$(wc -l < "$model_out/wav.scp")" = "$SAMPLE_COUNT"
  mkdir -p "$model_out/mos"
  python -u -m n019.eval_mos \
    --backend utmos \
    --wav-scp "$model_out/wav.scp" \
    --code-source "$ROOT/vendor/UTMOS22-demo" \
    --checkpoint "$UTMOS_CHECKPOINT" \
    --device "$DEVICE" \
    --out "$model_out/mos/UTMOS.json" \
    2>&1 | tee "$model_out/mos/UTMOS.log"
  python -u -m n019.eval_mos \
    --backend whisqa \
    --wav-scp "$model_out/wav.scp" \
    --code-source "$ROOT/vendor/WhiSQA" \
    --checkpoint "$WHISQA_CHECKPOINT" \
    --device "$DEVICE" \
    --out "$model_out/mos/WhiSQA.json" \
    2>&1 | tee "$model_out/mos/WhiSQA.log"
done

python - "$AUDIT" "${MODELS[@]}" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
summary = {}
for name in sys.argv[2:]:
    meta = json.loads((out / name / "run_meta.json").read_text(encoding="utf-8"))
    entry = {
        "steps": meta.get("vocoder_version"),
        "records": meta.get("records"),
        "input_sha256": meta.get("input_sha256"),
    }
    for metric in ("UTMOS", "WhiSQA"):
        report = json.loads(
            (out / name / "mos" / f"{metric}.json").read_text(encoding="utf-8")
        )
        entry[metric] = {
            "count": report["count"],
            "mean": report["mean"],
            "stddev": report["stddev"],
            "min": report["min"],
            "max": report["max"],
        }
    summary[name] = entry
(out / "summary.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2, sort_keys=True))
PY

if [[ "$(id -u)" == "0" ]]; then
  chown -R "$OWNER" "$AUDIT"
fi
echo "VOCODER_CHECKPOINT_AUDIT_MOS_COMPLETE out=$AUDIT"
