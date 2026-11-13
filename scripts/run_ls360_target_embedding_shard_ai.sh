#!/usr/bin/env bash

set -euo pipefail
umask 0002

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SHARD_INDEX="${N019_SHARD_INDEX:?N019_SHARD_INDEX is required}"
SHARD_MANIFEST="${N019_SHARD_MANIFEST:?N019_SHARD_MANIFEST is required}"
SHARD_ROOT="${N019_SHARD_OUT_ROOT:-$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_360_target_nt_utterance_shards}"
OUT="$SHARD_ROOT/shard_$(printf '%03d' "$SHARD_INDEX")"
MAX_SECONDS="${N019_SHARD_MAX_SECONDS:-72000}"

for required in \
  "$SHARD_MANIFEST" \
  "$N019_OFFICIAL_MODELS/wpro/config.json" \
  "$N019_OFFICIAL_MODELS/wpro/model.safetensors" \
  "$N019_OFFICIAL_MODELS/wpro/spk_embeddings.py"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing target embedding input: $required" >&2
    exit 1
  fi
done

mkdir -p "$OUT"
if [[ "$(id -u)" == "0" ]]; then
  # In AI containers $N019_VOICE_ROOT is /mnt/data and is root-owned.
  # Project data is created and owned by the SCNet account, so use that.
  owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
  chown "$owner" "$OUT"
fi
trap 'if [[ "$(id -u)" == "0" ]]; then chown -R "$owner" "$OUT" || true; fi' EXIT

RESUME_FLAG=()
if [[ -f "$OUT/partial_embeddings.npz" ]]; then
  RESUME_FLAG=(--resume)
fi

{
  echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
  echo "job=${SLURM_JOB_ID:-manual} scope=ls360_target_embedding_shard"
  echo "shard_index=$SHARD_INDEX"
  echo "manifest=$SHARD_MANIFEST"
  echo "rows=$(wc -l < "$SHARD_MANIFEST")"
  echo "out=$OUT"
  echo "resume=${#RESUME_FLAG[@]}"
  echo "max_seconds=$MAX_SECONDS"
  hy-smi || true
} | tee "$OUT/launch.txt"

bash "$ROOT/scripts/preflight_dcu_remote.sh"

timeout --signal=TERM "$MAX_SECONDS" \
  python -u -m n019.extract_speakers \
  --manifest "$SHARD_MANIFEST" \
  --model "$N019_OFFICIAL_MODELS/wpro" \
  --kind nt \
  --level utterance \
  --checkpoint-every "${N019_SHARD_CHECKPOINT_EVERY:-128}" \
  --device cuda \
  --out "$OUT" \
  "${RESUME_FLAG[@]}"

python - "$SHARD_MANIFEST" "$OUT" <<'PY'
import json
import sys
from pathlib import Path

import numpy as np

from n019.manifest import iter_jsonl, utterance_id

manifest = Path(sys.argv[1])
out = Path(sys.argv[2])
expected = {utterance_id(row) for row in iter_jsonl(manifest)}
archive = np.load(out / "nt_utterance_embeddings.npz", allow_pickle=False)
keys = set(archive.files)
dimensions = {int(archive[key].size) for key in keys}
finite = all(bool(np.isfinite(archive[key]).all()) for key in keys)
archive.close()
if keys != expected:
    missing = sorted(expected - keys)[:5]
    extra = sorted(keys - expected)[:5]
    raise SystemExit(f"NT shard ID mismatch: missing={missing} extra={extra}")
if dimensions != {250}:
    raise SystemExit(f"NT shard dimensions are {dimensions}, expected 250")
if not finite:
    raise SystemExit("NT shard contains non-finite embeddings")
print(
    json.dumps(
        {
            "status": "verified",
            "records": len(expected),
            "dimension": 250,
            "finite": finite,
        }
    )
)
PY

echo "LS360_TARGET_EMBEDDING_SHARD_COMPLETE out=$OUT"
