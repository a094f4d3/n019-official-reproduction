#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

MANIFEST="${N019_DEV_TARGET_MANIFEST:?Set N019_DEV_TARGET_MANIFEST}"
OUT="${N019_DEV_TARGET_OUT:?Set N019_DEV_TARGET_OUT}"
MODEL="${N019_DEV_TARGET_MODEL:-$N019_OFFICIAL_MODELS/wpro}"

test -f "$MANIFEST"
test -f "$MODEL/spk_embeddings.py"
python - "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

rows = [
    json.loads(line)
    for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
    if line.strip()
]
if len(rows) != 99:
    raise SystemExit(f"Expected 99 target utterances, got {len(rows)}")
ids = [str(row["id"]) for row in rows]
if len(ids) != len(set(ids)):
    raise SystemExit("Duplicate target utterance IDs")
missing = [row["audio"] for row in rows if not Path(row["audio"]).is_file()]
if missing:
    raise SystemExit(f"Missing target audio: {missing[0]}")
print(f"DEV_TARGET_MANIFEST_OK rows={len(rows)}")
PY

mkdir -p "$OUT"
python -u -m n019.extract_speakers \
  --manifest "$MANIFEST" \
  --model "$MODEL" \
  --kind nt \
  --level utterance \
  --checkpoint-every 25 \
  --device cuda \
  --out "$OUT"

python - "$OUT/nt_utterance_embeddings.npz" <<'PY'
import sys

import numpy as np

path = sys.argv[1]
archive = np.load(path, allow_pickle=False)
if len(archive.files) != 99:
    raise SystemExit(f"Expected 99 embeddings, got {len(archive.files)}")
for key in archive.files:
    value = archive[key]
    if value.shape != (250,):
        raise SystemExit(f"{key}: expected (250,), got {value.shape}")
    if not np.isfinite(value).all():
        raise SystemExit(f"{key}: non-finite embedding")
    norm = float(np.linalg.norm(value))
    if abs(norm - 1.0) > 1e-4:
        raise SystemExit(f"{key}: expected unit norm, got {norm}")
archive.close()
print("DEV_TARGET_EMBEDDINGS_OK count=99 dimension=250")
PY

sha256sum "$OUT/nt_utterance_embeddings.npz" "$OUT/metadata.json"
echo "N019_DEV_TARGET_SPARSE_COMPLETE out=$OUT"
