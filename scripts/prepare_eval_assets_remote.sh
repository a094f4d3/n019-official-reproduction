#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
PROCESSED="$DATA/processed"
MANIFESTS="$PROCESSED/manifests"
UNITS="$PROCESSED/units/libri_test"
TARGETS="$PROCESSED/targets"
EMBEDDINGS="$PROCESSED/embeddings/libri_test_target_nt_utterance"
CODEBOOK="$PROCESSED/units/librispeech_train_clean_100/kmeans_k200_seed20261102.npz"
DEVICE="${N019_DEVICE:-cuda}"

source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

mkdir -p "$UNITS" "$TARGETS" "$EMBEDDINGS"

if [[ ! -s "$MANIFESTS/libri_test.jsonl" ]]; then
  echo "STAGE_START libri_test_manifest $(date -Is)"
  python -u -m n019.prepare_vpc_manifest \
    --vpc-root "$DATA/vpc" \
    --subset libri_test \
    --out "$MANIFESTS/libri_test.jsonl"
fi

if [[ ! -s "$TARGETS/target_map.jsonl" ]]; then
  echo "STAGE_START target_map $(date -Is)"
  python -u -m n019.targets \
    --source-manifest "$MANIFESTS/libri_test.jsonl" \
    --target-manifest "$MANIFESTS/libritts_train_other_500.jsonl" \
    --seed 20261102 \
    --mode utterance \
    --out "$TARGETS/target_map.jsonl"
fi

if [[ ! -s "$TARGETS/target_manifest.jsonl" ]]; then
  echo "STAGE_START target_subset $(date -Is)"
  python -u -m n019.select_targets \
    --target-map "$TARGETS/target_map.jsonl" \
    --target-manifest "$MANIFESTS/libritts_train_other_500.jsonl" \
    --out "$TARGETS/target_manifest.jsonl"
fi

if [[ ! -s "$EMBEDDINGS/nt_utterance_embeddings.npz" ]] ||
   [[ ! -s "$EMBEDDINGS/metadata.json" ]]; then
  echo "STAGE_START target_embeddings $(date -Is)"
  python -u -m n019.extract_speakers \
    --manifest "$TARGETS/target_manifest.jsonl" \
    --model "$MODELS/wpro" \
    --kind nt \
    --level utterance \
    --checkpoint-every 100 \
    --resume \
    --device "$DEVICE" \
    --out "$EMBEDDINGS"
fi

test -s "$CODEBOOK"
if [[ ! -s "$UNITS/unit_records.jsonl" ]] ||
   [[ ! -s "$UNITS/units_metadata.json" ]]; then
  echo "STAGE_START libri_test_units $(date -Is)"
  python -u -m n019.units \
    --manifest "$MANIFESTS/libri_test.jsonl" \
    --out "$UNITS" \
    --hubert-model "$MODELS/hubert" \
    --codebook "$CODEBOOK" \
    --layer 6 \
    --k 200 \
    --seed 20261102 \
    --batch-size 16 \
    --workers 4 \
    --device "$DEVICE"
fi

{
  echo "account=$(id -un)"
  echo "host=$(hostname)"
  echo "completed_at=$(date -Is)"
  echo "libri_test_rows=$(wc -l < "$MANIFESTS/libri_test.jsonl")"
  echo "target_map_rows=$(wc -l < "$TARGETS/target_map.jsonl")"
  echo "target_rows=$(wc -l < "$TARGETS/target_manifest.jsonl")"
  echo "target_embeddings=$EMBEDDINGS/nt_utterance_embeddings.npz"
  echo "libri_test_units=$(wc -l < "$UNITS/unit_records.jsonl")"
} | tee "$ROOT/audit/eval_assets_complete.txt"

echo "EVAL_ASSETS_COMPLETE $(date -Is)"
