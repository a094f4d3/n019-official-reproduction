#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
OUT="$DATA/processed/manifests"
FORCE="${1:-}"

source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

LIBRISPEECH="$DATA/corpora/librispeech/LibriSpeech/train-clean-100"
LIBRITTS_TRAIN="$DATA/corpora/libritts/LibriTTS/train-clean-100"
LIBRITTS_TARGET="$DATA/corpora/libritts/LibriTTS/train-other-500"

test -d "$LIBRISPEECH"
test -d "$LIBRITTS_TRAIN"
test -d "$LIBRITTS_TARGET"

if [[ "$FORCE" != "--force" ]] &&
   [[ -s "$OUT/dataset_summary.json" ]] &&
   [[ -s "$OUT/librispeech_train_clean_100.jsonl" ]] &&
   [[ -s "$OUT/libritts_train_clean_100.jsonl" ]] &&
   [[ -s "$OUT/libritts_train_other_500.jsonl" ]]; then
  echo "MANIFESTS_ALREADY_PRESENT $OUT"
  exit 0
fi

echo "MANIFEST_BUILD_START $OUT"
python -u -m n019.prepare_data \
  --librispeech-train "$LIBRISPEECH" \
  --libritts-train "$LIBRITTS_TRAIN" \
  --libritts-target "$LIBRITTS_TARGET" \
  --out "$OUT"

sha256sum \
  "$OUT/librispeech_train_clean_100.jsonl" \
  "$OUT/libritts_train_clean_100.jsonl" \
  "$OUT/libritts_train_other_500.jsonl" \
  "$OUT/dataset_summary.json" \
  > "$ROOT/audit/official_manifests.sha256"

echo "MANIFESTS_COMPLETE $OUT"
