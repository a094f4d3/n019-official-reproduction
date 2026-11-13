#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SOURCE="$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360.jsonl"
TARGETS="$N019_OFFICIAL_DATA/processed/manifests/libritts_train_other_500.jsonl"
OUT="$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_map_utterance.jsonl"
TARGET_SUBSET="$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_manifest.jsonl"
SEED="${N019_TARGET_SEED:-20261102}"

for required in "$SOURCE" "$TARGETS"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing target-map input: $required" >&2
    exit 1
  fi
done
mkdir -p "$(dirname "$OUT")"

if [[ ! -f "$OUT" ]]; then
  python -u -m n019.targets \
    --source-manifest "$SOURCE" \
    --target-manifest "$TARGETS" \
    --seed "$SEED" \
    --mode utterance \
    --out "$OUT"
fi

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

map_path = Path(sys.argv[1])
meta_path = Path(f"{map_path}.meta.json")
meta = json.loads(meta_path.read_text(encoding="utf-8"))
if meta.get("mode") != "utterance":
    raise ValueError(
        f"Target map mode is {meta.get('mode')!r}, expected 'utterance'. "
        "Use a new output path instead of silently replacing a prior map."
    )
print(json.dumps({"target_map_meta": str(meta_path), "mode": "utterance"}))
PY

if [[ ! -s "$TARGET_SUBSET" ]]; then
  python -u -m n019.select_targets \
    --target-map "$OUT" \
    --target-manifest "$TARGETS" \
    --out "$TARGET_SUBSET"
fi

python - "$SOURCE" "$OUT" "$TARGET_SUBSET" <<'PY'
import json
import sys
from pathlib import Path

source_path, map_path, subset_path = map(Path, sys.argv[1:])

def read(path):
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]

sources = read(source_path)
mappings = read(map_path)
target_subset = read(subset_path)
source_ids = [row["id"] for row in sources]
mapped_ids = [row["source_id"] for row in mappings]
target_ids = {row["target_id"] for row in mappings}
subset_ids = {row["id"] for row in target_subset}
speakers = {str(row["speaker"]) for row in sources}
if len(sources) != 104_014:
    raise ValueError(f"Expected 104014 LS360 rows, got {len(sources)}")
if len(speakers) != 921:
    raise ValueError(f"Expected 921 LS360 speakers, got {len(speakers)}")
if len(mappings) != len(sources):
    raise ValueError(
        f"Target map has {len(mappings)} rows, expected {len(sources)}"
    )
if len(set(mapped_ids)) != len(mappings):
    raise ValueError("Target map contains duplicate source IDs")
if set(mapped_ids) != set(source_ids):
    raise ValueError("Target map source IDs do not match LS360 manifest")
if subset_ids != target_ids:
    raise ValueError("Selected LS360 target manifest does not match target map")
print(json.dumps({
    "source_rows": len(sources),
    "source_speakers": len(speakers),
    "target_map_rows": len(mappings),
    "target_utterances": len(target_ids),
    "target_subset_rows": len(target_subset),
}, indent=2))
PY

echo "LS360_TARGET_MAP_COMPLETE out=$OUT target_subset=$TARGET_SUBSET"
