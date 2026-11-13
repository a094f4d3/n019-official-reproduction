#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
WAV_SCP="$VPC_ROOT/libri_test_n019_ext102k/wav.scp"
WER_SRC="$N019_OFFICIAL_RUNS/eval/wer_native_cpu_recover/WER.json"
OUT="$N019_OFFICIAL_RUNS/eval/du_pred_nt_ext102k"
UTMOS_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt"
WHISQA_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"
WHISPER_SMALL_PATH="$N019_VOICE_ROOT/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d"
export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"
export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"

python - <<'PY'
import fairseq
import hydra
import omegaconf
import pytorch_lightning
PY

for required in \
  "$WAV_SCP" \
  "$WER_SRC" \
  "$UTMOS_CHECKPOINT" \
  "$WHISQA_CHECKPOINT" \
  "$WHISPER_SMALL_PATH/config.json" \
  "$ROOT/vendor/UTMOS22-demo/score.py" \
  "$ROOT/vendor/WhiSQA/models/whisper_ni_predictors.py"; do
  test -f "$required" || {
    echo "Missing ext102k MOS input: $required" >&2
    exit 1
  }
done
test "$(wc -l < "$WAV_SCP")" = 1934

python - "$WER_SRC" "$OUT" <<'PY'
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
out = Path(sys.argv[2])
result = json.loads(source.read_text(encoding="utf-8"))
if result["utterances"] != 1496 or result["references"] != 1496:
    raise SystemExit(f"Unexpected WER row count: {result}")
if not 0.0 <= float(result["wer"]) <= 1.0:
    raise SystemExit(f"Invalid WER: {result['wer']}")
out.mkdir(parents=True, exist_ok=True)
(out / "WER.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

mkdir -p "$OUT/mos"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "date=$(date -Is)"
  echo "scope=ext102k_mos_only_after_recovered_wer"
  echo "wav_scp=$WAV_SCP"
  echo "wer=$WER_SRC"
  echo "utmos=$UTMOS_CHECKPOINT"
  echo "whisqa=$WHISQA_CHECKPOINT"
  echo "whisper_small=$WHISPER_SMALL_PATH"
  echo "out=$OUT"
} | tee "$OUT/mos/launch.txt"

python -u -m n019.eval_mos \
  --backend utmos \
  --wav-scp "$WAV_SCP" \
  --vpc-data-root "$VPC_ROOT" \
  --code-source "$ROOT/vendor/UTMOS22-demo" \
  --checkpoint "$UTMOS_CHECKPOINT" \
  --device cpu \
  --out "$OUT/mos/UTMOS.json" \
  2>&1 | tee "$OUT/mos/UTMOS.log"

python -u -m n019.eval_mos \
  --backend whisqa \
  --wav-scp "$WAV_SCP" \
  --vpc-data-root "$VPC_ROOT" \
  --code-source "$ROOT/vendor/WhiSQA" \
  --checkpoint "$WHISQA_CHECKPOINT" \
  --device cpu \
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
    raise SystemExit(f"WER count mismatch: {wer['utterances']}")
if int(utmos["count"]) != 1934 or int(whisqa["count"]) != 1934:
    raise SystemExit(
        f"MOS count mismatch: UTMOS={utmos['count']} WhiSQA={whisqa['count']}"
    )

paper = {"WER": 7.41, "UTMOS": 3.63, "WhiSQA": 3.69}
step4k = {"WER": 10.333, "UTMOS": 1.2620579278580035, "WhiSQA": 1.847028814125209}
values = {
    "WER": float(wer["wer_percent"]),
    "UTMOS": float(utmos["mean"]),
    "WhiSQA": float(whisqa["mean"]),
}

def comparisons(reference):
    result = {}
    for name in ("WER", "UTMOS", "WhiSQA"):
        absolute = values[name] - reference[name]
        result[name] = {
            "reference": reference[name],
            "reproduced": values[name],
            "absolute_difference": absolute,
            "relative_difference_percent": absolute / reference[name] * 100.0,
        }
    return result

summary = {
    "system": "DU-pred-nt-ext102k",
    "vocoder_steps": 102000,
    "vocoder_sha256": "62eb5908aae998f50eed1456a8f6a8f606a88c07627c1d92517f0d072c9ff151",
    "values": values,
    "vs_paper": comparisons(paper),
    "vs_step4k_full": comparisons(step4k),
    "notes": [
        "WER uses the VPC2024 SpeechBrain-aligned native CPU path over 1496 utterances.",
        "UTMOS and WhiSQA are evaluated independently over the same 1934 ext102k WAVs.",
        "E-VPC I/L and W-NT I/L were not recomputed in this MOS-only run.",
    ],
}
(out / "quality_metrics.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2, sort_keys=True))
PY

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
chown -R "$owner" "$OUT"
sha256sum \
  "$OUT/WER.json" \
  "$OUT/mos/UTMOS.json" \
  "$OUT/mos/WhiSQA.json" \
  "$OUT/quality_metrics.json"
echo "DU_PRED_NT_EXT102K_WER_MOS_COMPLETE out=$OUT"
