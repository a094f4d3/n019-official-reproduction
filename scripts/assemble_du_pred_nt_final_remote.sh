#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

OUT="${N019_FINAL_OUT:?Set N019_FINAL_OUT}"
IL_EVPC="${N019_IL_EVPC:?Set N019_IL_EVPC}"
S_EVAL="${N019_S_EVAL:?Set N019_S_EVAL}"
IL_WNT="${N019_IL_WNT:?Set N019_IL_WNT}"
S_WNT="${N019_S_WNT:?Set N019_S_WNT}"
WER_JSON="${N019_WER_JSON:?Set N019_WER_JSON}"
UTMOS_JSON="${N019_UTMOS_JSON:?Set N019_UTMOS_JSON}"
WHISQA_JSON="${N019_WHISQA_JSON:?Set N019_WHISQA_JSON}"

for required in \
  "$IL_EVPC" "$S_EVAL" "$IL_WNT" "$S_WNT" \
  "$WER_JSON" "$UTMOS_JSON" "$WHISQA_JSON"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing final DU-pred-nt metric source: $required" >&2
    exit 1
  fi
done

mkdir -p "$OUT"

python - "$WER_JSON" "$UTMOS_JSON" "$WHISQA_JSON" <<'PY'
import json
import sys
from pathlib import Path

wer_path, utmos_path, whisqa_path = map(Path, sys.argv[1:])
wer = json.loads(wer_path.read_text(encoding="utf-8"))
utmos = json.loads(utmos_path.read_text(encoding="utf-8"))
whisqa = json.loads(whisqa_path.read_text(encoding="utf-8"))
if int(wer.get("utterances", -1)) != 1496:
    raise SystemExit(f"WER utterance count is not 1496: {wer.get('utterances')}")
if int(utmos.get("count", -1)) != 1934:
    raise SystemExit(f"UTMOS count is not 1934: {utmos.get('count')}")
if int(whisqa.get("count", -1)) != 1934:
    raise SystemExit(f"WhiSQA count is not 1934: {whisqa.get('count')}")
print("QUALITY_COUNTS_OK WER=1496 UTMOS=1934 WhiSQA=1934")
PY

python "$ROOT/scripts/merge_wnt_attack_summaries.py" \
  --summary "$IL_WNT" \
  --summary "$S_WNT" \
  --require I L S \
  --out "$OUT/wnt_summary_ils.json" \
  2>&1 | tee "$OUT/merge_wnt_ils.log"

python -m n019.assemble_paper_metrics \
  --system "DU-pred-nt" \
  --evpc "$IL_EVPC" \
  --s-eval "$S_EVAL" \
  --wnt-summary "$OUT/wnt_summary_ils.json" \
  --wer-json "$WER_JSON" \
  --wer-condition anon \
  --utmos "$UTMOS_JSON" \
  --whisqa "$WHISQA_JSON" \
  --out "$OUT/paper_metrics.json"

python - "$OUT/paper_metrics.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
required = {
    "E-VPC I",
    "E-VPC L",
    "E-VPC S",
    "W-NT I",
    "W-NT L",
    "W-NT S",
    "WER",
    "UTMOS",
    "WhiSQA",
}
missing = data.get("missing", [])
values = data.get("values", {})
if missing:
    raise SystemExit(f"Final metrics are incomplete: missing={missing}")
if set(values) != required:
    raise SystemExit(
        f"Final metric schema mismatch: got={sorted(values)} expected={sorted(required)}"
    )
print("FINAL_METRIC_COUNTS=9")
PY

python -m n019.compare_paper \
  --paper-table "$ROOT/configs/paper_table1.json" \
  --system "DU-pred-nt" \
  --metrics "$OUT/paper_metrics.json" \
  --out-json "$OUT/paper_comparison.json" \
  --out-md "$OUT/paper_comparison.md"

sha256sum \
  "$OUT/wnt_summary_ils.json" \
  "$OUT/paper_metrics.json" \
  "$OUT/paper_comparison.json" \
  "$OUT/paper_comparison.md" \
  | tee "$OUT/SHA256SUMS.txt"

echo "N019_DU_PRED_NT_FINAL_COMPLETE out=$OUT"
