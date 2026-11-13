#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d4/voice_projects/code/n019_official
DATA=/public/home/a094f4d4/voice_projects/data/n019_official/processed
MODEL=/public/home/a094f4d4/voice_projects/models/n019_official/wpro
source "$ROOT/hpc/activate_n019_official.sh" >/dev/null
cd "$ROOT"

SOURCE="$DATA/manifests/libri_test_paperfix.jsonl"
FULL_TARGET="$DATA/manifests/libritts_train_other_500.jsonl"
TARGET_MAP="$DATA/targets/libri_test_target_map_paperfix.jsonl"
TARGET_MANIFEST="$DATA/targets/libri_test_target_manifest_paperfix.jsonl"
EMBEDDINGS="$DATA/embeddings/libri_test_target_nt_utterance_paperfix"

test "$(wc -l < "$SOURCE")" = 1934
test "$(wc -l < "$FULL_TARGET")" = 205044

if [[ ! -s "$TARGET_MAP" ]]; then
  python -u -m n019.targets \
    --source-manifest "$SOURCE" \
    --target-manifest "$FULL_TARGET" \
    --seed 20261102 \
    --mode utterance \
    --out "$TARGET_MAP"
fi
if [[ ! -s "$TARGET_MANIFEST" ]]; then
  python -u -m n019.select_targets \
    --target-map "$TARGET_MAP" \
    --target-manifest "$FULL_TARGET" \
    --out "$TARGET_MANIFEST"
fi

python - "$SOURCE" "$TARGET_MAP" "$TARGET_MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

source_path, map_path, target_path = map(Path, sys.argv[1:])
source_ids = {json.loads(line)["id"] for line in source_path.open()}
rows = [json.loads(line) for line in map_path.open()]
targets = [json.loads(line) for line in target_path.open()]
map_ids = {row["source_id"] for row in rows}
target_ids = [row["id"] for row in targets]
if map_ids != source_ids:
    raise SystemExit("libri_test source/target-map ID mismatch")
if {row["target_id"] for row in rows} != set(target_ids):
    raise SystemExit("target-map/target-manifest target ID mismatch")
if len(target_ids) != len(set(target_ids)):
    raise SystemExit("duplicate target IDs")
print(f"SOURCE_ROWS={len(source_ids)} TARGET_ROWS={len(rows)} UNIQUE_TARGETS={len(target_ids)}")
PY

mkdir -p "$EMBEDDINGS"
python -u -m n019.extract_speakers \
  --manifest "$TARGET_MANIFEST" \
  --model "$MODEL" \
  --kind nt \
  --level utterance \
  --checkpoint-every 100 \
  --resume \
  --device cuda \
  --out "$EMBEDDINGS"

python - "$TARGET_MANIFEST" "$EMBEDDINGS/nt_utterance_embeddings.npz" <<'PY'
import json
import sys
from pathlib import Path

import numpy as np

manifest_path, npz_path = map(Path, sys.argv[1:])
ids = [json.loads(line)["id"] for line in manifest_path.open()]
archive = np.load(npz_path, allow_pickle=False)
try:
    if set(archive.files) != set(ids):
        raise SystemExit("embedding/manifest ID mismatch")
    for key in ids:
        value = archive[key]
        if value.shape != (250,):
            raise SystemExit(f"bad embedding shape for {key}: {value.shape}")
        if not np.isfinite(value).all():
            raise SystemExit(f"non-finite embedding for {key}")
        norm = float(np.linalg.norm(value))
        if abs(norm - 1.0) > 1e-4:
            raise SystemExit(f"bad embedding norm for {key}: {norm}")
finally:
    archive.close()
print(f"EMBEDDINGS_OK rows={len(ids)} dim=250")
PY

owner="$(stat -c '%u:%g' "$DATA")"
chown -R "$owner" \
  "$TARGET_MAP" \
  "$TARGET_MANIFEST" \
  "$EMBEDDINGS"

sha256sum "$TARGET_MAP" "$TARGET_MANIFEST" \
  "$EMBEDDINGS/nt_utterance_embeddings.npz" \
  "$EMBEDDINGS/metadata.json"
echo LIBRI_TEST_TARGET_EMBEDDING_PAPERFIX_COMPLETE
