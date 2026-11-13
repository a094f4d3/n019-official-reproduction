#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d4/voice_projects/code/n019_official
DATA=/public/home/a094f4d4/voice_projects/data/n019_official/processed
PYTHON=/public/home/a094f4d4/voice_projects/envs/n019/bin/python
export PYTHONPATH="$ROOT/compat:$ROOT/src"

SOURCE="$DATA/manifests/libri_test_paperfix.jsonl"
FULL_TARGET="$DATA/manifests/libritts_train_other_500.jsonl"
TARGET_MAP="$DATA/targets/libri_test_target_map_paperfix.jsonl"
TARGET_MANIFEST="$DATA/targets/libri_test_target_manifest_paperfix.jsonl"

test "$(wc -l < "$SOURCE")" = 1934
test "$(wc -l < "$FULL_TARGET")" = 205044
mkdir -p "$DATA/targets"

"$PYTHON" -u -m n019.targets \
  --source-manifest "$SOURCE" \
  --target-manifest "$FULL_TARGET" \
  --seed 20261102 \
  --mode utterance \
  --out "$TARGET_MAP"

"$PYTHON" -u -m n019.select_targets \
  --target-map "$TARGET_MAP" \
  --target-manifest "$FULL_TARGET" \
  --out "$TARGET_MANIFEST"

"$PYTHON" - "$SOURCE" "$TARGET_MAP" "$TARGET_MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

source_path, map_path, target_path = map(Path, sys.argv[1:])
source_ids = {json.loads(line)["id"] for line in source_path.open()}
rows = [json.loads(line) for line in map_path.open()]
targets = [json.loads(line) for line in target_path.open()]
map_ids = {row["source_id"] for row in rows}
target_ids = [row["id"] for row in targets]
if len(source_ids) != 1934 or map_ids != source_ids:
    raise SystemExit("libri_test source/target-map ID mismatch")
if {row["target_id"] for row in rows} != set(target_ids):
    raise SystemExit("target-map/target-manifest target ID mismatch")
if len(target_ids) != len(set(target_ids)):
    raise SystemExit("duplicate target IDs")
print(f"SOURCE_ROWS={len(source_ids)}")
print(f"TARGET_ROWS={len(rows)}")
print(f"UNIQUE_TARGETS={len(target_ids)}")
PY

sha256sum "$SOURCE" "$TARGET_MAP" "$TARGET_MANIFEST"
echo LIBRI_TEST_TARGET_MAP_PAPERFIX_COMPLETE
