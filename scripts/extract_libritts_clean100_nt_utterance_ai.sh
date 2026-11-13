#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

RECORDS="${N019_CLEAN100_RECORDS:?Set N019_CLEAN100_RECORDS}"
OUT="${N019_CLEAN100_UTTERANCE_OUT:?Set N019_CLEAN100_UTTERANCE_OUT}"
MODEL="$N019_OFFICIAL_MODELS/wpro"

test -f "$RECORDS"
test -f "$MODEL/spk_embeddings.py"
rows="$(wc -l < "$RECORDS")"
test "$rows" = 33236

echo "records=$RECORDS rows=$rows"
echo "model=$MODEL"
echo "out=$OUT"
python - <<'PY'
import torch
if not torch.cuda.is_available():
    raise SystemExit("CUDA/DCU unavailable")
print(f"device={torch.cuda.get_device_name(0)}")
PY

mkdir -p "$OUT"
python -u -m n019.extract_speakers \
  --manifest "$RECORDS" \
  --model "$MODEL" \
  --kind nt \
  --level utterance \
  --checkpoint-every 100 \
  --resume \
  --device cuda \
  --out "$OUT"

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

import numpy as np

out = Path(sys.argv[1])
archive_path = out / "nt_utterance_embeddings.npz"
metadata_path = out / "metadata.json"
archive = np.load(archive_path, allow_pickle=False)
keys = archive.files
if len(keys) != 33236:
    raise SystemExit(f"expected 33236 embeddings, got {len(keys)}")
seen = set(keys)
for key in keys:
    value = archive[key]
    if value.shape != (250,):
        raise SystemExit(f"{key}: expected (250,), got {value.shape}")
    if not np.isfinite(value).all():
        raise SystemExit(f"{key}: non-finite values")
    norm = float(np.linalg.norm(value))
    if not 0.999 <= norm <= 1.001:
        raise SystemExit(f"{key}: non-unit norm {norm}")
archive.close()
metadata = json.loads(metadata_path.read_text())
if metadata.get("level") != "utterance":
    raise SystemExit(f"metadata level={metadata.get('level')!r}")
if int(metadata.get("utterances", -1)) != 33236:
    raise SystemExit(f"metadata utterances={metadata.get('utterances')}")
print(
    json.dumps(
        {
            "status": "verified",
            "count": len(seen),
            "dimension": 250,
            "level": "utterance",
            "archive": str(archive_path),
        },
        indent=2,
    )
)
PY

sha256sum "$OUT/nt_utterance_embeddings.npz" "$OUT/metadata.json"
echo "N019_CLEAN100_NT_UTTERANCE_COMPLETE out=$OUT"
