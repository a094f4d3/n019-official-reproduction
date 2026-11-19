#!/bin/bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SRC_RECORDS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libri_test_paperfix/unit_records.jsonl
SRC_CODES_ROOT=/public/home/a094f4d7/voice_projects/data/n019_official/processed/units/libri_test_paperfix
SRC_TARGET_MAP=/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl
SRC_TARGET_EMB=/public/home/a094f4d7/voice_projects/data/n019_official/processed/embeddings/libri_test_target_nt_utterance_paperfix/nt_utterance_embeddings.npz
SRC_VOCODER=/public/home/a094f4d6/voice_projects/tmp/n019_privacy_fix_20261111/generator_soup2.pt
SRC_DURATION=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_nt_main/best.pt

BUNDLE="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117"
UNIT_DIR="$BUNDLE/units"
ASSET_DIR="$BUNDLE/assets"
mkdir -p "$UNIT_DIR/codes" "$ASSET_DIR"

tar -C "$SRC_CODES_ROOT/codes" -cf - . | tar -C "$UNIT_DIR/codes" -xf -
cp -f "$SRC_RECORDS" "$BUNDLE/unit_records.source.jsonl"
rm -f "$UNIT_DIR/unit_records.jsonl"
python scripts/rewrite_unit_record_roots.py \
  --input "$BUNDLE/unit_records.source.jsonl" \
  --output "$UNIT_DIR/unit_records.jsonl" \
  --old-root "$SRC_CODES_ROOT" \
  --new-root "$UNIT_DIR"
rm -f "$BUNDLE/unit_records.source.jsonl"

cp -f "$SRC_TARGET_MAP" "$BUNDLE/target_map.jsonl"
cp -f "$SRC_TARGET_EMB" "$ASSET_DIR/target_nt_utterance.npz"
cp -f "$SRC_VOCODER" "$ASSET_DIR/generator_soup2.pt"
cp -f "$SRC_DURATION" "$ASSET_DIR/duration_nt_main.pt"

python - "$BUNDLE" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
records = root / "units/unit_records.jsonl"
rows = [
    json.loads(line)
    for line in records.read_text(encoding="utf-8").splitlines()
    if line.strip()
]
if len(rows) != 1934:
    raise SystemExit(f"Expected 1934 records, got {len(rows)}")
missing = [row["codes_path"] for row in rows if not Path(row["codes_path"]).is_file()]
if missing:
    raise SystemExit(f"Missing {len(missing)} codes; first={missing[0]}")
codes = list((root / "units/codes").glob("*.npy"))
if len(codes) != 1934:
    raise SystemExit(f"Expected 1934 code files, got {len(codes)}")

files = [
    records,
    root / "target_map.jsonl",
    root / "assets/target_nt_utterance.npz",
    root / "assets/generator_soup2.pt",
    root / "assets/duration_nt_main.pt",
]
hashes = {}
for path in files:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    hashes[str(path.relative_to(root))] = digest.hexdigest()
metadata = {
    "purpose": "Self-contained DU-nt-nt test bundle using target utterance embeddings.",
    "records": 1934,
    "codes": 1934,
    "target_embedding_key": "target_id",
    "target_embedding_mode": "utterance",
    "duration_mode": "nt",
    "duration_training_embedding_level": "speaker",
    "sha256": hashes,
}
(root / "metadata.json").write_text(
    json.dumps(metadata, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(metadata, indent=2, sort_keys=True))
PY

echo "N019_DU_NT_NT_BUNDLE_COMPLETE bundle=$BUNDLE"
