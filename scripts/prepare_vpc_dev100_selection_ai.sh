#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export N019_OFFICIAL_ROOT="$ROOT"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

RAW="${N019_DEV100_RAW:-$N019_OFFICIAL_DATA/processed/selection_dev100_vpc_20261108}"
OUT="${N019_DEV100_OUT:-$N019_OFFICIAL_DATA/processed/selection_dev100_vpc_units_20261108}"
MANIFEST="$RAW/manifest.jsonl"
CODEBOOK="$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_100/kmeans_k200_seed20261102.npz"
HUBERT="$N019_OFFICIAL_MODELS/hubert"
WPRO="$N019_OFFICIAL_MODELS/wpro"
REUSE_UNITS="${N019_DEV100_REUSE_UNITS:-0}"

test "$(wc -l < "$MANIFEST")" = 100
test "$(sha256sum "$MANIFEST" | awk '{print $1}')" = \
  26de28d291efc45d615c13ec968dfc85760e86cba1a70a1395100d1a09d4a20a
test "$(sha256sum "$CODEBOOK" | awk '{print $1}')" = \
  a5cc08f707301a1c05da4ab4b00cd280dec66533796a976c3ac4743287eaf446
test -f "$HUBERT/config.json"
test -f "$WPRO/config.json"
if [[ "$REUSE_UNITS" == "1" ]]; then
  test "$(wc -l < "$OUT/units/unit_records.jsonl")" = 100
  test "$(find "$OUT/units/codes" -type f -name '*.npy' | wc -l)" = 100
  echo "reuse_units=$OUT/units"
else
  test ! -e "$OUT"
  mkdir -p "$OUT/units" "$OUT/embeddings"
  python -u -m n019.units \
    --manifest "$MANIFEST" \
    --out "$OUT/units" \
    --hubert-model "$HUBERT" \
    --codebook "$CODEBOOK" \
    --layer 6 \
    --k 200 \
    --seed 20261102 \
    --batch-size 16 \
    --workers 0 \
    --device cuda
fi

test -d "$OUT/embeddings" || mkdir -p "$OUT/embeddings"

python -u -m n019.extract_speakers \
  --manifest "$MANIFEST" \
  --model "$WPRO" \
  --kind nt \
  --level speaker \
  --checkpoint-every 100 \
  --device cuda \
  --out "$OUT/embeddings"

python - "$MANIFEST" "$OUT" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

manifest, out = map(Path, sys.argv[1:])
rows = [json.loads(line) for line in manifest.open() if line.strip()]
if len(rows) != 100 or len({row["speaker"] for row in rows}) != 40:
    raise SystemExit("Unexpected dev manifest composition")
unit_rows = [
    json.loads(line)
    for line in (out / "units/unit_records.jsonl").open()
    if line.strip()
]
if len(unit_rows) != 100:
    raise SystemExit(f"Unexpected unit row count: {len(unit_rows)}")
archive = np.load(
    out / "embeddings/nt_speaker_embeddings.npz",
    allow_pickle=False,
)
try:
    speakers = {row["speaker"] for row in rows}
    if set(archive.files) != speakers:
        raise SystemExit("Speaker embedding keys do not match manifest")
    for key in archive.files:
        value = archive[key]
        if value.shape != (250,):
            raise SystemExit(f"Bad embedding shape for {key}: {value.shape}")
        if not np.isfinite(value).all():
            raise SystemExit(f"Non-finite embedding for {key}")
        if abs(float(np.linalg.norm(value)) - 1.0) > 1e-4:
            raise SystemExit(f"Bad embedding norm for {key}")
finally:
    archive.close()

def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()

summary = {
    "rows": len(rows),
    "speakers": len(speakers),
    "manifest_sha256": sha256(manifest),
    "unit_records_sha256": sha256(out / "units/unit_records.jsonl"),
    "embedding_npz_sha256": sha256(
        out / "embeddings/nt_speaker_embeddings.npz"
    ),
    "embedding_metadata_sha256": sha256(
        out / "embeddings/metadata.json"
    ),
}
(out / "verify.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2, sort_keys=True))
PY

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
chown -R "$owner" "$OUT"
sha256sum "$OUT/verify.json"
echo VPC_DEV100_SELECTION_ASSETS_COMPLETE out="$OUT"
