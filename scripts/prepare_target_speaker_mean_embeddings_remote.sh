#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
export PYTHONPATH="$ROOT/src${PYTHONPATH:+:$PYTHONPATH}"

DATA="${N019_OFFICIAL_DATA:-$N019_VOICE_ROOT/data/n019_official}"
SOURCE_NPZ="${N019_TARGET_POOL_SOURCE_NPZ:-$DATA/processed/embeddings/libri_test_target_nt_utterance_paperfix/nt_utterance_embeddings.npz}"
TARGET_MAP="${N019_TARGET_POOL_TARGET_MAP:-$DATA/processed/targets/libri_test_target_map_paperfix.jsonl}"
OUT="${N019_TARGET_POOL_OUT:-$DATA/processed/embeddings/libri_test_target_nt_speaker_mean_l2_paperfix}"

for required in "$SOURCE_NPZ" "$TARGET_MAP"; do
  test -f "$required" || {
    echo "Missing target-pooling input: $required" >&2
    exit 1
  }
done
mkdir -p "$OUT"
python -m n019.target_embedding_pooling \
  --embeddings "$SOURCE_NPZ" \
  --target-map "$TARGET_MAP" \
  --key-mode target_speaker \
  --out "$OUT/nt_target_speaker_embeddings.npz" \
  --report "$OUT/metadata.json"
sha256sum "$OUT/nt_target_speaker_embeddings.npz" "$OUT/metadata.json"
echo "N019_TARGET_SPEAKER_MEAN_READY out=$OUT"
