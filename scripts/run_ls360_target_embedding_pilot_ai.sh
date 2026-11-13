#!/usr/bin/env bash

set -euo pipefail
umask 0002

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -f "$ROOT/hpc/activate_n019_official.sh" ]]; then
  ROOT=""
  for candidate in \
    /mnt/data/voice_projects/code/n019_official \
    "/public/home/$(id -un)/voice_projects/code/n019_official" \
    "$HOME/voice_projects/code/n019_official"; do
    if [[ -d "$candidate" ]]; then
      ROOT="$candidate"
      break
    fi
  done
fi

if [[ -z "${ROOT:-}" ]]; then
  echo "Cannot locate n019_official project root" >&2
  echo "user=$(id -un) home=$HOME" >&2
  exit 1
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SOURCE="$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_manifest.jsonl"
MANIFEST="$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_manifest_256.jsonl"
STAMP=$(date +%Y%m%d_%H%M%S)
OUT="$N019_OFFICIAL_RUNS/ls360_target_embedding_pilot_ai_${STAMP}"

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing target manifest: $SOURCE" >&2
  exit 1
fi
if [[ ! -f "$MANIFEST" ]]; then
  head -n 256 "$SOURCE" > "$MANIFEST.tmp"
  mv "$MANIFEST.tmp" "$MANIFEST"
fi
if [[ "$(wc -l < "$MANIFEST")" != "256" ]]; then
  echo "Pilot manifest must contain 256 rows" >&2
  exit 1
fi

mkdir -p "$OUT"
if [[ "$(id -u)" == "0" ]]; then
  owner="$(stat -c '%u:%g' "$N019_VOICE_ROOT")"
  chown "$owner" "$OUT"
  chown "$owner" "$MANIFEST"
fi
trap 'if [[ "$(id -u)" == "0" ]]; then chown -R "$owner" "$OUT" || true; fi' EXIT
START=$(date +%s)
{
  echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
  echo "mode=ai_model_training scope=ls360_target_embedding_pilot"
  echo "source=$SOURCE"
  echo "manifest=$MANIFEST rows=256"
  echo "out=$OUT"
  echo "wall_budget_seconds=600"
  hy-smi || true
} | tee "$OUT/launch.txt"

bash "$N019_OFFICIAL_ROOT/scripts/preflight_dcu_remote.sh"

timeout --signal=TERM 540 \
  python -u -m n019.extract_speakers \
  --manifest "$MANIFEST" \
  --model "$N019_OFFICIAL_MODELS/wpro" \
  --kind nt \
  --level utterance \
  --checkpoint-every 64 \
  --device cuda \
  --out "$OUT"

END=$(date +%s)
ELAPSED=$((END - START))
python - "$OUT" "$ELAPSED" "$MANIFEST" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch

out = Path(sys.argv[1])
elapsed = float(sys.argv[2])
manifest = Path(sys.argv[3])
archive_path = out / "nt_utterance_embeddings.npz"
archive = np.load(archive_path, allow_pickle=False)
values = {
    key: torch.from_numpy(archive[key].astype(np.float32))
    for key in archive.files
}
archive.close()
ids = {
    json.loads(line)["id"]
    for line in manifest.read_text(encoding="utf-8").splitlines()
    if line.strip()
}
if set(values) != ids:
    raise ValueError("Pilot embedding IDs do not match the 256-row manifest")
if any(value.numel() != 250 for value in values.values()):
    raise ValueError("Pilot embedding dimension is not 250")
if any(not bool(torch.isfinite(value).all()) for value in values.values()):
    raise ValueError("Pilot embedding contains non-finite values")
norms = torch.stack([value.norm() for value in values.values()])
if not bool(torch.allclose(norms, torch.ones_like(norms), atol=1e-4)):
    raise ValueError("Pilot embeddings are not L2-normalized")
summary = {
    "rows": len(values),
    "elapsed_seconds_including_model_load": elapsed,
    "utterances_per_second": len(values) / elapsed,
    "projected_seconds_for_81605": 81605 / (len(values) / elapsed),
    "dimension": 250,
    "minimum_norm": float(norms.min()),
    "maximum_norm": float(norms.max()),
    "embeddings_sha256": hashlib.sha256(
        archive_path.read_bytes()
    ).hexdigest(),
}
(out / "pilot_throughput.json").write_text(
    json.dumps(summary, indent=2) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2))
PY

echo "LS360_TARGET_EMBEDDING_AI_PILOT_COMPLETE out=$OUT"
