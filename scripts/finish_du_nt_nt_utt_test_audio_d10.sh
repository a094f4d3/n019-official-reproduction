#!/bin/bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-/public/home/a094f4d10/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

BUNDLE="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117"
SOURCE_AUDIO="/public/home/a094f4d7/voice_projects/data/n019_official/vpc/data/libri_test/wav"
RECORDS="$BUNDLE/units/unit_records.jsonl"
TEMP="$BUNDLE/units/unit_records.audio_tmp.jsonl"

test -d "$SOURCE_AUDIO"
test -s "$RECORDS"
test ! -e "$TEMP"
mkdir -p "$BUNDLE/audio"

tar -C "$SOURCE_AUDIO" -cf - . | tar -C "$BUNDLE/audio" -xf -

python scripts/rewrite_unit_record_roots.py \
  --input "$RECORDS" \
  --output "$TEMP" \
  --old-root "$SOURCE_AUDIO" \
  --new-root "$BUNDLE/audio"
mv "$TEMP" "$RECORDS"

python - "$BUNDLE" <<'PY'
import json
import sys
from pathlib import Path

bundle = Path(sys.argv[1])
records = [
    json.loads(line)
    for line in (bundle / "units/unit_records.jsonl").read_text().splitlines()
    if line.strip()
]
if len(records) != 1934:
    raise SystemExit(f"Expected 1934 records, got {len(records)}")
missing = [row["audio"] for row in records if not Path(row["audio"]).is_file()]
codes_missing = [
    row["codes_path"] for row in records if not Path(row["codes_path"]).is_file()
]
audio_files = list((bundle / "audio").glob("*.wav"))
if missing:
    raise SystemExit(f"Missing {len(missing)} audio files; first={missing[0]}")
if codes_missing:
    raise SystemExit(f"Missing {len(codes_missing)} code files; first={codes_missing[0]}")
if len(audio_files) != 1934:
    raise SystemExit(f"Expected 1934 audio files, got {len(audio_files)}")
print(f"BUNDLE_AUDIO_OK records={len(records)} audio={len(audio_files)}")
PY

python - "$BUNDLE" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

bundle = Path(sys.argv[1])
records = bundle / "units/unit_records.jsonl"
digest = hashlib.sha256()
with records.open("rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        digest.update(chunk)
metadata_path = bundle / "metadata.json"
metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
metadata["audio_files"] = 1934
metadata.setdefault("sha256", {})["units/unit_records.jsonl"] = digest.hexdigest()
metadata_path.write_text(
    json.dumps(metadata, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(f"BUNDLE_METADATA_UPDATED records_sha256={digest.hexdigest()}")
PY

echo "N019_DU_NT_NT_AUDIO_COMPLETE bundle=$BUNDLE"
