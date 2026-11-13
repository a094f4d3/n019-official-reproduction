#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SHARDS="${N019_LS360_SHARDS:-4}"
EXPECTED_RECORDS="${N019_LS360_EXPECTED_RECORDS:-104014}"
SOURCE="${N019_SOURCE_MANIFEST:-$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360.jsonl}"
UNITS="${N019_UNIT_RECORDS:-$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_360/unit_records.jsonl}"
TARGET_MAP="${N019_TARGET_MAP:-$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_map_utterance.jsonl}"
SHARD_ROOT="${N019_LS360_SHARD_ROOT:-$N019_OFFICIAL_RUNS/ls360_anonymise_shards_20261110}"
OUT="${N019_ANON_OUT:?Set N019_ANON_OUT to the merged output directory}"
SUFFIX="${N019_DATA_SUFFIX:?Set N019_DATA_SUFFIX}"

python "$ROOT/scripts/prepare_ls360_anonymise_shards.py" \
  --source-manifest "$SOURCE" \
  --unit-records "$UNITS" \
  --target-map "$TARGET_MAP" \
  --out-dir "$SHARD_ROOT" \
  --shards "$SHARDS" \
  --expected-records "$EXPECTED_RECORDS"

pids=()
for ((index = 0; index < SHARDS; index++)); do
  shard_dir="$SHARD_ROOT/shard_$index"
  mkdir -p "$shard_dir/anon"
  HIP_VISIBLE_DEVICES="$index" \
  CUDA_VISIBLE_DEVICES="$index" \
  N019_SOURCE_MANIFEST="$shard_dir/manifest.jsonl" \
  N019_UNIT_RECORDS="$shard_dir/unit_records.jsonl" \
  N019_TARGET_MAP="$shard_dir/target_map.jsonl" \
  N019_ANON_OUT="$shard_dir/anon" \
  N019_SKIP_VPC_EXPORT=1 \
  N019_DATA_SUFFIX="$SUFFIX" \
  N019_DURATION_MODE=pred \
  N019_VOCODER_TYPE=nt \
  N019_TARGET_EMBEDDING_KEY=target_speaker \
  N019_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1 \
    bash "$ROOT/scripts/anonymize_ls360_remote.sh" \
    > "$SHARD_ROOT/shard_$index.log" 2>&1 &
  pids+=("$!")
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done
if (( status != 0 )); then
  echo "At least one anonymisation shard failed" >&2
  exit "$status"
fi

python "$ROOT/scripts/merge_ls360_anonymisation_shards.py" \
  --source-manifest "$SOURCE" \
  --shard-root "$SHARD_ROOT" \
  --shards "$SHARDS" \
  --out-dir "$OUT" \
  --expected-records "$EXPECTED_RECORDS"

python -m n019.export_vpc_anon \
  --vpc-data-dir "$N019_OFFICIAL_DATA/vpc/data" \
  --anon-manifest "$OUT/anon.jsonl" \
  --suffix "$SUFFIX" \
  --dataset-name train-clean-360 \
  --overwrite-missing

python "$ROOT/scripts/verify_anonymized_outputs.py" \
  --source-manifest "$SOURCE" \
  --out-dir "$OUT" \
  --vpc-suffix-dir "$N019_OFFICIAL_DATA/vpc/data/train-clean-360$SUFFIX" \
  --duration-mode pred \
  --vocoder-type nt \
  --expected-records "$EXPECTED_RECORDS" \
  --out "$OUT/verification.json"

echo "LS360_SHARDED_ANONYMISATION_COMPLETE out=$OUT shards=$SHARDS"
