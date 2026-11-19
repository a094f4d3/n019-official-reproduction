#!/usr/bin/env bash

set -euo pipefail

ROOT="/public/home/a094f4d10/voice_projects/code/n019_official"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="/public/home/a094f4d10/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

OUT="$N019_OFFICIAL_RUNS/smoke_du_ecapa_nt_20261117"
BUNDLE="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117"
mkdir -p "$OUT"

if [[ "$(id -u)" == "0" ]]; then
  owner="$(stat -c '%u:%g' "$N019_OFFICIAL_RUNS")"
  trap 'chown -R "$owner" "$OUT" 2>/dev/null || true' EXIT
fi

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

python - "$BUNDLE/units/unit_records.jsonl" "$BUNDLE/target_map.jsonl" "$OUT" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

records_path, target_map_path, out = map(Path, sys.argv[1:])

def rows(path):
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                yield json.loads(line)

records = list(rows(records_path))[:8]
source_ids = {str(row["id"]) for row in records}
mappings = [
    row for row in rows(target_map_path)
    if str(row["source_id"]) in source_ids
][:8]
if len(mappings) != 8:
    raise SystemExit("Unable to select eight mapped smoke records")

(out / "records8.jsonl").write_text(
    "".join(json.dumps(row, sort_keys=True) + "\n" for row in records),
    encoding="utf-8",
)
(out / "records2.jsonl").write_text(
    "".join(json.dumps(row, sort_keys=True) + "\n" for row in records[:2]),
    encoding="utf-8",
)
(out / "target_map2.jsonl").write_text(
    "".join(json.dumps(row, sort_keys=True) + "\n" for row in mappings[:2]),
    encoding="utf-8",
)

keys = {str(row["speaker"]) for row in records}
keys.update(str(row["target_speaker"]) for row in mappings)
vectors = {}
for key in sorted(keys):
    digest = hashlib.sha256(key.encode("utf-8")).digest()
    raw = np.frombuffer((digest * 6)[:192], dtype=np.uint8).astype(np.float32)
    raw = raw - 127.5
    raw /= np.linalg.norm(raw)
    vectors[key] = raw
np.savez(out / "ecapa_toy.npz", **vectors)
print(json.dumps({"records": len(records), "mappings": len(mappings), "keys": len(keys)}))
PY

python -u -m n019.duration \
  --records "$OUT/records8.jsonl" \
  --embeddings "$OUT/ecapa_toy.npz" \
  --speaker-dim 192 \
  --embedding-kind ecapa \
  --epochs 1 \
  --batch-size 2 \
  --workers 0 \
  --device cuda \
  --out "$OUT/duration" 2>&1 | tee "$OUT/duration.log"

test -s "$OUT/duration/best.pt"

python -u -m n019.anonymize \
  --source-manifest "$OUT/records2.jsonl" \
  --unit-records "$OUT/records8.jsonl" \
  --target-map "$OUT/target_map2.jsonl" \
  --vocoder "$BUNDLE/assets/generator_soup2.pt" \
  --vocoder-type nt \
  --vocoder-embeddings "$BUNDLE/assets/target_nt_utterance.npz" \
  --target-embedding-key target_id \
  --target-embedding-mode utterance \
  --duration-mode ecapa \
  --duration-model "$OUT/duration/best.pt" \
  --duration-embeddings "$OUT/ecapa_toy.npz" \
  --duration-embedding-key target_speaker \
  --out-dir "$OUT/anonymised" \
  --overwrite \
  --skip-space-check \
  --device cuda 2>&1 | tee "$OUT/anonymize.log"

test "$(wc -l < "$OUT/anonymised/anon.jsonl")" = 2
test "$(find "$OUT/anonymised" -maxdepth 1 -type f -name '*.wav' | wc -l)" = 2
sha256sum \
  "$OUT/ecapa_toy.npz" \
  "$OUT/duration/best.pt" \
  "$OUT/anonymised/anon.jsonl"
echo "DU_ECAPA_NT_SMOKE_COMPLETE out=$OUT"
