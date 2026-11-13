#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

RUNS="$N019_OFFICIAL_RUNS"
INPUT="$RUNS/audit/vocoder_checkpoint_cpu_20261106/ext102k/inputs"
OUT="${N019_ORIG_DURATION_AUDIT_OUT:-$RUNS/audit/vocoder_checkpoint_cpu_20261106/orig_duration_main76k}"
VOCAB="$RUNS/vocoder_nt_main/best.pt"
TARGET_EMBEDDINGS="$N019_OFFICIAL_DATA/processed/embeddings/libri_test_target_nt_utterance_paperfix/nt_utterance_embeddings.npz"
DURATION_MODEL="$RUNS/duration_pred_paperfix/best.pt"
MOS_MODELS="$N019_OFFICIAL_MODELS/mos"
UTMOS_CHECKPOINT="$MOS_MODELS/UTMOS22-mirror/model.ckpt"
WHISQA_CHECKPOINT="$MOS_MODELS/WhiSQA_single_head.pt"
WHISPER_SMALL_PATH="${N019_WHISPER_SMALL_PATH:-$HF_HOME/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d}"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"

for required in \
  "$INPUT/source.jsonl" \
  "$INPUT/units.jsonl" \
  "$INPUT/target_map.jsonl" \
  "$VOCAB" \
  "$TARGET_EMBEDDINGS" \
  "$UTMOS_CHECKPOINT" \
  "$WHISQA_CHECKPOINT" \
  "$WHISPER_SMALL_PATH/config.json" \
  "$ROOT/vendor/UTMOS22-demo/score.py" \
  "$ROOT/vendor/WhiSQA/models/whisper_ni_predictors.py"; do
  test -f "$required" || {
    echo "Missing original-duration diagnostic input: $required" >&2
    exit 1
  }
done

mkdir -p "$OUT"
sha256sum "$VOCAB" | tee "$OUT/vocoder.sha256"
python -u -m n019.anonymize \
  --source-manifest "$INPUT/source.jsonl" \
  --unit-records "$INPUT/units.jsonl" \
  --target-map "$INPUT/target_map.jsonl" \
  --duration-mode orig \
  --duration-model "$DURATION_MODEL" \
  --vocoder "$VOCAB" \
  --vocoder-type nt \
  --vocoder-embeddings "$TARGET_EMBEDDINGS" \
  --out-dir "$OUT" \
  --device cpu \
  --skip-space-check \
  --overwrite \
  2>&1 | tee "$OUT/anonymize.log"

python - "$OUT/anon.jsonl" "$OUT/wav.scp" <<'PY'
import json
import sys
from pathlib import Path

manifest, output = map(Path, sys.argv[1:])
rows = [
    json.loads(line)
    for line in manifest.read_text(encoding="utf-8").splitlines()
    if line.strip()
]
if len(rows) != 25:
    raise SystemExit(f"Expected 25 rows, got {len(rows)}")
output.write_text(
    "".join(f"{row['id']} {row['audio']}\n" for row in rows),
    encoding="utf-8",
)
PY

export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"
export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"
mkdir -p "$OUT/mos"
python -u -m n019.eval_mos \
  --backend utmos \
  --wav-scp "$OUT/wav.scp" \
  --code-source "$ROOT/vendor/UTMOS22-demo" \
  --checkpoint "$UTMOS_CHECKPOINT" \
  --device cpu \
  --out "$OUT/mos/UTMOS.json" \
  2>&1 | tee "$OUT/mos/UTMOS.log"
python -u -m n019.eval_mos \
  --backend whisqa \
  --wav-scp "$OUT/wav.scp" \
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
meta = json.loads((out / "run_meta.json").read_text(encoding="utf-8"))
summary = {
    "steps": meta.get("vocoder_version"),
    "records": meta.get("records"),
    "input_sha256": meta.get("input_sha256"),
    "duration_mode": "orig",
}
for metric in ("UTMOS", "WhiSQA"):
    report = json.loads((out / "mos" / f"{metric}.json").read_text(encoding="utf-8"))
    summary[metric] = {
        "count": report["count"],
        "mean": report["mean"],
        "stddev": report["stddev"],
        "min": report["min"],
        "max": report["max"],
    }
(out / "summary.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2, sort_keys=True))
PY

echo "VOCODER_ORIG_DURATION_AUDIT_COMPLETE out=$OUT"
