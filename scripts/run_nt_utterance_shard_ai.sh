#!/usr/bin/env bash

set -euo pipefail

: "${N019_SHARD_MANIFEST:?Set N019_SHARD_MANIFEST}"
: "${N019_SHARD_OUT:?Set N019_SHARD_OUT}"
: "${N019_BASE_PARTIAL:=}"

ROOT="${N019_OFFICIAL_ROOT:-/public/home/a094f4d6/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

RECORDS="/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libritts_train_clean_100/unit_records.jsonl"
MODEL="/public/home/a094f4d6/voice_projects/models/n019_official/wpro"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"
test -f "$N019_SHARD_MANIFEST"
test -f "$RECORDS"
test -f "$MODEL/spk_embeddings.py"

shard_rows="$(wc -l <"$N019_SHARD_MANIFEST")"
if (( shard_rows < 1 )); then
  echo "Empty shard manifest: $N019_SHARD_MANIFEST" >&2
  exit 1
fi

mkdir -p "$N019_SHARD_OUT"
if [[ -n "$N019_BASE_PARTIAL" ]]; then
  test -f "$N019_BASE_PARTIAL"
  cp --sparse=always "$N019_BASE_PARTIAL" "$N019_SHARD_OUT/partial_embeddings.npz"
fi

echo "shard_manifest=$N019_SHARD_MANIFEST rows=$shard_rows"
echo "shard_out=$N019_SHARD_OUT"
echo "base_partial=${N019_BASE_PARTIAL:-none}"

python -u -m n019.extract_speakers \
  --manifest "$N019_SHARD_MANIFEST" \
  --model "$MODEL" \
  --kind nt \
  --level utterance \
  --checkpoint-every 100 \
  --resume \
  --device cuda \
  --out "$N019_SHARD_OUT"

owner="$(stat -c '%u:%g' /public/home/a094f4d6/voice_projects/data/n019_official)"
chown -R "$owner" "$N019_SHARD_OUT"
