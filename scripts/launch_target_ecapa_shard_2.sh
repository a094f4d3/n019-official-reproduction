#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/hpc/activate_n019_official.sh" >/dev/null
export N019_SHARD_INDEX=2
export N019_SHARD_MANIFEST="$N019_OFFICIAL_DATA/processed/targets/embedding_shards_4/shard_002.jsonl"
export N019_SHARD_MAX_SECONDS="${N019_SHARD_MAX_SECONDS:-64800}"
exec bash "$ROOT/scripts/run_ls360_target_ecapa_shard_ai.sh"
