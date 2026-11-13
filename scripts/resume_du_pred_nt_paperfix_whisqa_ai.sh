#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SUFFIX="_n019_paperfix"
RUN_NAME="du_pred_nt_paperfix"
OUT="$N019_OFFICIAL_RUNS/eval/$RUN_NAME"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
ANON="$N019_OFFICIAL_DATA/anonymised/libri_test/DU-pred-nt-paperfix"
WHISQA_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt"
WHISPER_SMALL_PATH="$N019_VOICE_ROOT/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d"
export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"

for required in \
  "$OUT/evpc/evpc_metrics.json" \
  "$OUT/summary.json" \
  "$OUT/mos/UTMOS.json" \
  "$ANON/anon.jsonl" \
  "$VPC_ROOT/libri_test$SUFFIX/wav.scp" \
  "$ROOT/vendor/WhiSQA/models/whisper_ni_predictors.py" \
  "$WHISPER_SMALL_PATH/config.json" \
  "$WHISQA_CHECKPOINT"; do
  test -f "$required" || {
    echo "Missing WhiSQA resume input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$VPC_ROOT/libri_test$SUFFIX/wav.scp")" = 1934

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
utmos = json.loads((out / "mos" / "UTMOS.json").read_text(encoding="utf-8"))
if int(utmos["count"]) != 1934:
    raise SystemExit(f"Existing UTMOS count={utmos['count']}, expected 1934")
evpc = json.loads((out / "evpc" / "evpc_metrics.json").read_text())
summary = json.loads((out / "summary.json").read_text())
if not {"I", "L"}.issubset(evpc.get("paper_conditions", {})):
    raise SystemExit("Existing E-VPC metrics do not contain I and L")
if "anon" not in evpc.get("wer_percent", {}):
    raise SystemExit("Existing E-VPC metrics do not contain anonymous WER")
if not {"I", "L"}.issubset(summary.get("attacks", {})):
    raise SystemExit("Existing W-NT summary does not contain I and L")
PY

python - "$WHISPER_SMALL_PATH" <<'PY'
import sys
from transformers import WhisperConfig, WhisperFeatureExtractor, WhisperTokenizer

repo = sys.argv[1]
WhisperConfig.from_pretrained(repo, local_files_only=True)
WhisperFeatureExtractor.from_pretrained(repo, local_files_only=True)
WhisperTokenizer.from_pretrained(repo, local_files_only=True)
print("WHISPER_SMALL_OFFLINE_OK", repo)
PY

mkdir -p "$OUT/mos"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "date=$(date -Is)"
  echo "scope=resume_whisqa_only"
  echo "suffix=$SUFFIX"
  echo "out=$OUT"
} | tee "$OUT/mos/whisqa_resume_launch.txt"

python -u -m n019.eval_mos \
  --backend whisqa \
  --wav-scp "$VPC_ROOT/libri_test$SUFFIX/wav.scp" \
  --vpc-data-root "$VPC_ROOT" \
  --code-source "$ROOT/vendor/WhiSQA" \
  --checkpoint "$WHISQA_CHECKPOINT" \
  --device cuda \
  --out "$OUT/mos/WhiSQA.json" \
  2>&1 | tee "$OUT/mos/WhiSQA.log"

python -m n019.assemble_paper_metrics \
  --system DU-pred-nt \
  --evpc "$OUT/evpc/evpc_metrics.json" \
  --wnt-summary "$OUT/summary.json" \
  --wer-json "$OUT/evpc/evpc_metrics.json" \
  --wer-condition anon \
  --utmos "$OUT/mos/UTMOS.json" \
  --whisqa "$OUT/mos/WhiSQA.json" \
  --out "$OUT/paper_metrics.json"

python -m n019.compare_paper \
  --paper-table "$ROOT/configs/paper_table1.json" \
  --system DU-pred-nt \
  --metrics "$OUT/paper_metrics.json" \
  --out-json "$OUT/paper_comparison.json" \
  --out-md "$OUT/paper_comparison.md"

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
metrics = json.loads((out / "paper_metrics.json").read_text(encoding="utf-8"))
missing = set(metrics.get("missing", []))
if missing != {"E-VPC S", "W-NT S"}:
    raise SystemExit(
        f"Unexpected incomplete I/L/WER/MOS metric set: {sorted(missing)}"
    )
for name in ("UTMOS", "WhiSQA"):
    report = json.loads(
        (out / "mos" / f"{name}.json").read_text(encoding="utf-8")
    )
    if int(report["count"]) != 1934:
        raise SystemExit(
            f"{name} evaluated {report['count']} files, expected 1934"
        )
print("PAPERFIX_I_L_WER_MOS_COMPLETE; S_METRICS_PENDING")
PY

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
chown -R "$owner" "$OUT"
sha256sum \
  "$OUT/evpc/evpc_metrics.json" \
  "$OUT/summary.json" \
  "$OUT/mos/UTMOS.json" \
  "$OUT/mos/WhiSQA.json" \
  "$OUT/paper_metrics.json" \
  "$OUT/paper_comparison.json" \
  "$OUT/paper_comparison.md"
echo "DU_PRED_NT_PAPERFIX_WHISQA_RESUME_COMPLETE out=$OUT"
