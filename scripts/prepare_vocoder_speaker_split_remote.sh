#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
export PYTHONPATH="$ROOT/src${PYTHONPATH:+:$PYTHONPATH}"

DATA="${N019_OFFICIAL_DATA:-$N019_VOICE_ROOT/data/n019_official}"
INPUT="${N019_VOCODER_SPLIT_INPUT:-$DATA/processed/units/libritts_train_clean_100/unit_records.jsonl}"
MANIFEST="${N019_VOCODER_SPLIT_MANIFEST:-$DATA/processed/manifests/libritts_train_clean_100.jsonl}"
OUT="${N019_VOCODER_SPLIT_OUT:-$DATA/processed/units/libritts_train_clean_100_speaker_split_seed20261102}"
FRACTION="${N019_VOCODER_SPLIT_DEV_FRACTION:-0.05}"
SEED="${N019_VOCODER_SPLIT_SEED:-20261102}"

test -f "$INPUT" || {
  echo "Missing vocoder split input: $INPUT" >&2
  exit 1
}
test -f "$MANIFEST" || {
  echo "Missing vocoder split source manifest: $MANIFEST" >&2
  exit 1
}
mkdir -p "$OUT"
python -m n019.split_manifest \
  --input "$INPUT" \
  --train-out "$OUT/unit_records_train.jsonl" \
  --dev-out "$OUT/unit_records_dev.jsonl" \
  --dev-fraction "$FRACTION" \
  --seed "$SEED"
python - "$MANIFEST" "$OUT/unit_records_train.jsonl.split.json" \
  "$OUT/manifest_train.jsonl" "$OUT/manifest_dev.jsonl" <<'PY'
import json
import sys
from pathlib import Path

manifest = Path(sys.argv[1])
split_info = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
dev_speakers = set(map(str, split_info["dev_speakers"]))
train_rows = []
dev_rows = []
for line in manifest.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    row = json.loads(line)
    speaker = str(row.get("speaker") or row.get("speaker_id"))
    target = dev_rows if speaker in dev_speakers else train_rows
    target.append(line)
Path(sys.argv[3]).write_text("\n".join(train_rows) + "\n", encoding="utf-8")
Path(sys.argv[4]).write_text("\n".join(dev_rows) + "\n", encoding="utf-8")
if not train_rows or not dev_rows:
    raise SystemExit("Speaker-disjoint manifest split produced an empty side")
print(f"manifest_train={len(train_rows)} manifest_dev={len(dev_rows)}")
PY
sha256sum \
  "$OUT/unit_records_train.jsonl" \
  "$OUT/unit_records_dev.jsonl" \
  "$OUT/unit_records_train.jsonl.split.json" \
  "$OUT/manifest_train.jsonl" \
  "$OUT/manifest_dev.jsonl" \
  | tee "$OUT/SHA256SUMS.txt"
echo "N019_VOCODER_SPEAKER_SPLIT_READY out=$OUT"
