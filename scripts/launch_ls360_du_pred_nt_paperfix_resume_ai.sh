#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

OUT="${N019_ANON_OUT:-$N019_OFFICIAL_DATA/anonymised/ls360/DU-pred-nt-paperfix}"
VPC_OUT="${N019_OFFICIAL_DATA}/vpc/data/train-clean-360_n019_paperfix"
PARTIAL="$OUT/anon.partial.jsonl"
ACCOUNT="${OUT#/public/home/}"
ACCOUNT="${ACCOUNT%%/*}"
if [[ "$ACCOUNT" != "a094f4d6" ]]; then
  echo "Refusing unexpected output owner target: $ACCOUNT" >&2
  exit 1
fi

if [[ -e "$OUT/anon.jsonl" ]]; then
  echo "Refusing to resume: final anon.jsonl already exists in $OUT" >&2
  exit 1
fi
if [[ ! -f "$PARTIAL" ]]; then
  echo "Refusing to resume: missing $PARTIAL" >&2
  exit 1
fi

PARTIAL_LINES="$(wc -l < "$PARTIAL")"
echo "paperfix_resume_partial_lines=$PARTIAL_LINES"
if (( PARTIAL_LINES < 93350 )); then
  echo "Refusing to resume: partial has fewer rows than the verified timeout checkpoint" >&2
  exit 1
fi

python - "$PARTIAL" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open("rb") as handle:
    handle.seek(0, 2)
    size = handle.tell()
    handle.seek(max(0, size - 65536))
    tail = handle.read()
if not tail.endswith(b"\n"):
    raise SystemExit("partial JSONL does not end with a complete newline")
last = tail.rstrip(b"\n").rsplit(b"\n", 1)[-1]
row = json.loads(last)
if not row.get("id") or not row.get("audio"):
    raise SystemExit("last partial JSON row is missing id/audio")
print(f"paperfix_resume_last_row={row['id']}")
PY

set +e
timeout --signal=TERM 5400 env \
  N019_DATA_SUFFIX=_n019_paperfix \
  N019_DURATION_MODE=pred \
  N019_VOCODER_TYPE=nt \
  N019_DURATION_MODEL="$N019_OFFICIAL_RUNS/duration_pred_paperfix/best.pt" \
  N019_VOCODER="$N019_OFFICIAL_RUNS/vocoder_nt_paperfix/best.pt" \
  N019_ANON_OUT="$OUT" \
  bash -x "$ROOT/scripts/anonymize_ls360_remote.sh" \
  > "$ROOT/audit/ls360_du_pred_nt_paperfix_resume_inner.log" 2>&1
RUN_RC=$?
set -e

echo "paperfix_resume_inner_rc=$RUN_RC"
OWNER="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
if [[ "$OWNER" == "0:0" ]]; then
  echo "Refusing to chown output to root: $N019_OFFICIAL_DATA" >&2
  exit 3
fi
chown -R "$OWNER" "$OUT"
if [[ -e "$VPC_OUT" ]]; then
  chown -R "$OWNER" "$VPC_OUT"
fi

if (( RUN_RC != 0 )); then
  exit "$RUN_RC"
fi
echo "LS360_PAPERFIX_RESUME_COMPLETE out=$OUT"
