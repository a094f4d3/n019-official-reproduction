#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export N019_ECAPA_MANIFEST="$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_100.jsonl"
export N019_ECAPA_EMBEDDINGS_OUT="$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_100_ecapa"
export N019_ECAPA_EXPECTED_SPEAKERS=251

exec bash "$ROOT/scripts/extract_ecapa_embeddings_remote.sh"
