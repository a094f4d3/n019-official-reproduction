#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
MANIFESTS="$DATA/processed/manifests"
PROCESSED="$DATA/processed"
DEVICE="${N019_DEVICE:-cuda}"

source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

HUBERT="$MODELS/hubert"
WPRO="$MODELS/wpro"
LS_MANIFEST="$MANIFESTS/librispeech_train_clean_100.jsonl"
TTS_MANIFEST="$MANIFESTS/libritts_train_clean_100.jsonl"
LS_UNITS="$PROCESSED/units/librispeech_train_clean_100"
TTS_UNITS="$PROCESSED/units/libritts_train_clean_100"
LS_SPEAKERS="$PROCESSED/embeddings/librispeech_train_clean_100_nt"
TTS_SPEAKERS="$PROCESSED/embeddings/libritts_train_clean_100_nt"
CODEBOOK="$LS_UNITS/kmeans_k200_seed20261102.npz"

test -s "$LS_MANIFEST"
test -s "$TTS_MANIFEST"
test -d "$HUBERT"
test -d "$WPRO"
mkdir -p "$LS_UNITS" "$TTS_UNITS" "$LS_SPEAKERS" "$TTS_SPEAKERS"

if [[ ! -s "$LS_UNITS/unit_records.jsonl" ]] ||
   [[ ! -s "$LS_UNITS/units_metadata.json" ]]; then
  echo "STAGE_START librispeech_units $(date -Is)"
  python -u -m n019.units \
    --manifest "$LS_MANIFEST" \
    --out "$LS_UNITS" \
    --hubert-model "$HUBERT" \
    --layer 6 \
    --k 200 \
    --seed 20261102 \
    --batch-size 16 \
    --workers 4 \
    --device "$DEVICE"
fi

test -s "$CODEBOOK"

if [[ ! -s "$LS_SPEAKERS/nt_speaker_embeddings.npz" ]] ||
   [[ ! -s "$LS_SPEAKERS/metadata.json" ]]; then
  echo "STAGE_START librispeech_speakers $(date -Is)"
  python -u -m n019.extract_speakers \
    --manifest "$LS_MANIFEST" \
    --model "$WPRO" \
    --kind nt \
    --level speaker \
    --checkpoint-every 500 \
    --resume \
    --device "$DEVICE" \
    --out "$LS_SPEAKERS"
fi

if [[ ! -s "$TTS_UNITS/unit_records.jsonl" ]] ||
   [[ ! -s "$TTS_UNITS/units_metadata.json" ]]; then
  echo "STAGE_START libritts_units $(date -Is)"
  python -u -m n019.units \
    --manifest "$TTS_MANIFEST" \
    --out "$TTS_UNITS" \
    --hubert-model "$HUBERT" \
    --codebook "$CODEBOOK" \
    --layer 6 \
    --k 200 \
    --seed 20261102 \
    --batch-size 16 \
    --workers 4 \
    --device "$DEVICE"
fi

if [[ ! -s "$TTS_SPEAKERS/nt_speaker_embeddings.npz" ]] ||
   [[ ! -s "$TTS_SPEAKERS/metadata.json" ]]; then
  echo "STAGE_START libritts_speakers $(date -Is)"
  python -u -m n019.extract_speakers \
    --manifest "$TTS_MANIFEST" \
    --model "$WPRO" \
    --kind nt \
    --level speaker \
    --checkpoint-every 500 \
    --resume \
    --device "$DEVICE" \
    --out "$TTS_SPEAKERS"
fi

{
  echo "account=$(id -un)"
  echo "host=$(hostname)"
  echo "completed_at=$(date -Is)"
  echo "librispeech_units=$(wc -l < "$LS_UNITS/unit_records.jsonl")"
  echo "libritts_units=$(wc -l < "$TTS_UNITS/unit_records.jsonl")"
  echo "codebook=$CODEBOOK"
  echo "librispeech_speakers=$LS_SPEAKERS/nt_speaker_embeddings.npz"
  echo "libritts_speakers=$TTS_SPEAKERS/nt_speaker_embeddings.npz"
} | tee "$ROOT/audit/unit_pipeline_complete.txt"

echo "UNIT_PIPELINE_COMPLETE $(date -Is)"
