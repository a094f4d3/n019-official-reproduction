#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SHARD_INDEX="${N019_TARGET_SHARD_INDEX:?Set N019_TARGET_SHARD_INDEX}"
SHARD_COUNT="${N019_TARGET_SHARD_COUNT:-2}"
MANIFEST="${N019_TARGET_SHARD_MANIFEST:?Set N019_TARGET_SHARD_MANIFEST}"
OUT="${N019_TARGET_SHARD_OUT:?Set N019_TARGET_SHARD_OUT}"
MODEL="$N019_OFFICIAL_MODELS/wpro"

test "$SHARD_COUNT" = 2
case "$SHARD_INDEX" in
  0|1) ;;
  *) echo "N019_TARGET_SHARD_INDEX must be 0 or 1" >&2; exit 1 ;;
esac
test -f "$MANIFEST"
test -f "$MODEL/spk_embeddings.py"

echo "target_mean_shard=${SHARD_INDEX}/${SHARD_COUNT}"
echo "manifest=$MANIFEST rows=$(wc -l < "$MANIFEST")"
echo "out=$OUT"
echo "device=$(python - <<'PY'
import torch
print("cuda" if torch.cuda.is_available() else "cpu")
PY
)"

mkdir -p "$OUT"
python -u -m n019.extract_speakers \
  --manifest "$MANIFEST" \
  --model "$MODEL" \
  --kind nt \
  --level speaker \
  --checkpoint-every 200 \
  --resume \
  --device cuda \
  --out "$OUT"

sha256sum "$OUT/nt_speaker_embeddings.npz" "$OUT/metadata.json"
echo "N019_TARGET_SPEAKER_MEAN_SHARD_COMPLETE shard=$SHARD_INDEX out=$OUT"
