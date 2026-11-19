#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SOURCE="${N019_SOURCE_MANIFEST:-$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360.jsonl}"
UNITS="${N019_UNIT_RECORDS:-$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_360/unit_records.jsonl}"
TARGET_MAP="${N019_TARGET_MAP:-$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_map_utterance.jsonl}"
SUFFIX="${N019_DATA_SUFFIX:-_n019}"
DURATION_MODE="${N019_DURATION_MODE:-pred}"
DURATION_EMBEDDING_KEY="${N019_DURATION_EMBEDDING_KEY:-target_id}"
VOCODER_TYPE="${N019_VOCODER_TYPE:-nt}"
TARGET_EMBEDDING_KEY="${N019_TARGET_EMBEDDING_KEY:-target_id}"
TARGET_EMBEDDING_MODE="${N019_TARGET_EMBEDDING_MODE:-provided}"

case "$VOCODER_TYPE" in
  nt)
    TARGET_EMBEDDING_DEFAULT="$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_360_target_nt_utterance/nt_utterance_embeddings.npz"
    VOCODER_DEFAULT="$N019_OFFICIAL_RUNS/vocoder_nt_main/best.pt"
    ;;
  ecapa)
    TARGET_EMBEDDING_DEFAULT="$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_360_target_ecapa_utterance/ecapa_utterance_embeddings.npz"
    VOCODER_DEFAULT="$N019_OFFICIAL_RUNS/vocoder_ecapa_main/best.pt"
    ;;
  *)
    echo "N019_VOCODER_TYPE must be nt or ecapa" >&2
    exit 1
    ;;
esac

TARGET_EMBEDDINGS="${N019_VOCODER_EMBEDDINGS:-$TARGET_EMBEDDING_DEFAULT}"
DURATION_EMBEDDINGS="${N019_DURATION_EMBEDDINGS:-}"
VOCODER="${N019_VOCODER:-$VOCODER_DEFAULT}"
OUT="${N019_ANON_OUT:-$N019_OFFICIAL_DATA/anonymised/ls360/DU-${DURATION_MODE}-${VOCODER_TYPE}}"

DURATION_MODEL_ARGS=()
DURATION_EMBEDDING_ARGS=()
case "$DURATION_MODE" in
  orig)
    ;;
  pred)
    DURATION_MODEL="${N019_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_pred_main/best.pt}"
    DURATION_MODEL_ARGS=(--duration-model "$DURATION_MODEL")
    ;;
  nt)
    DURATION_MODEL="${N019_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_nt_main/best.pt}"
    DURATION_MODEL_ARGS=(--duration-model "$DURATION_MODEL")
    DURATION_EMBEDDINGS="${DURATION_EMBEDDINGS:-$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_360_target_nt_utterance/nt_utterance_embeddings.npz}"
    DURATION_EMBEDDING_ARGS=(--duration-embeddings "$DURATION_EMBEDDINGS")
    ;;
  ecapa)
    DURATION_MODEL="${N019_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_ecapa_main/best.pt}"
    DURATION_MODEL_ARGS=(--duration-model "$DURATION_MODEL")
    if [[ -z "$DURATION_EMBEDDINGS" ]]; then
      DURATION_EMBEDDINGS="$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_360_target_ecapa_utterance/ecapa_utterance_embeddings.npz"
    fi
    DURATION_EMBEDDING_ARGS=(--duration-embeddings "$DURATION_EMBEDDINGS")
    ;;
  *)
    echo "N019_DURATION_MODE must be orig, pred, nt, or ecapa" >&2
    exit 1
    ;;
esac

REQUIRED_INPUTS=(
  "$SOURCE" \
  "$UNITS" \
  "$TARGET_MAP" \
  "$TARGET_EMBEDDINGS" \
  "$VOCODER" \
  "$N019_OFFICIAL_DATA/vpc/data/train-clean-360/wav.scp"
)
if [[ "$DURATION_MODE" != "orig" ]]; then
  REQUIRED_INPUTS+=("$DURATION_MODEL")
fi
if [[ ${#DURATION_EMBEDDING_ARGS[@]} -gt 0 ]]; then
  REQUIRED_INPUTS+=("$DURATION_EMBEDDINGS")
fi

for required in "${REQUIRED_INPUTS[@]}"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing LS360 anonymisation input: $required" >&2
    exit 1
  fi
done

mkdir -p "$OUT"
RESUME_FLAG=()
if [[ -f "$OUT/anon.partial.jsonl" ]]; then
  RESUME_FLAG=(--resume)
fi

{
  echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
  echo "job=${SLURM_JOB_ID:-manual} scope=ls360_anonymisation"
  echo "duration_mode=$DURATION_MODE"
  echo "duration_model=${DURATION_MODEL:-none}"
  echo "duration_embeddings=${DURATION_EMBEDDINGS:-none}"
  echo "duration_embedding_key=$DURATION_EMBEDDING_KEY"
  echo "vocoder_type=$VOCODER_TYPE"
  echo "vocoder=$VOCODER"
  echo "vocoder_embeddings=$TARGET_EMBEDDINGS"
  echo "target_embedding_key=$TARGET_EMBEDDING_KEY"
  echo "target_embedding_mode=$TARGET_EMBEDDING_MODE"
  echo "out=$OUT"
  echo "resume=${#RESUME_FLAG[@]}"
} | tee "$OUT/launch.txt"

python - "$TARGET_MAP" "$TARGET_EMBEDDINGS" "$TARGET_EMBEDDING_KEY" <<'PY'
import json
import sys

import numpy as np

target_map_path, embeddings_path, key_name = sys.argv[1:]
archive = np.load(embeddings_path, allow_pickle=False)
available = set(archive.files)
required = set()
with open(target_map_path, encoding="utf-8") as handle:
    for line in handle:
        if line.strip():
            required.add(str(json.loads(line)[key_name]))
missing = sorted(required - available)
if missing:
    raise SystemExit(
        f"Missing {len(missing)} target embedding keys; first: {missing[:10]}"
    )
dimensions = {int(archive[key].size) for key in required}
if dimensions != {250}:
    raise SystemExit(f"Unexpected target embedding dimensions: {dimensions}")
for key in required:
    value = archive[key]
    if not np.isfinite(value).all():
        raise SystemExit(f"Non-finite target embedding: {key}")
    norm = float(np.linalg.norm(value))
    if abs(norm - 1.0) > 1e-4:
        raise SystemExit(f"Target embedding is not unit-normalized: {key} {norm}")
archive.close()
print(f"TARGET_EMBEDDING_PREFLIGHT_OK keys={len(required)} mode_key={key_name}")
PY

python -u -m n019.anonymize \
  --source-manifest "$SOURCE" \
  --unit-records "$UNITS" \
  --target-map "$TARGET_MAP" \
  --duration-mode "$DURATION_MODE" \
  "${DURATION_MODEL_ARGS[@]}" \
  "${DURATION_EMBEDDING_ARGS[@]}" \
  --duration-embedding-key "$DURATION_EMBEDDING_KEY" \
  --vocoder "$VOCODER" \
  --vocoder-type "$VOCODER_TYPE" \
  --vocoder-embeddings "$TARGET_EMBEDDINGS" \
  --target-embedding-key "$TARGET_EMBEDDING_KEY" \
  --target-embedding-mode "$TARGET_EMBEDDING_MODE" \
  --speaker-embedding-scale "${N019_SPEAKER_EMBEDDING_SCALE:-1.0}" \
  --duration-extrapolation "${N019_DURATION_EXTRAPOLATION:-0.0}" \
  ${N019_DURATION_PRESERVE_TOTAL:+--duration-preserve-total} \
  --duration-soft-cap-frames "${N019_DURATION_SOFT_CAP_FRAMES:-0.0}" \
  --out-dir "$OUT" \
  --device cuda \
  "${RESUME_FLAG[@]}"

if [[ "${N019_SKIP_VPC_EXPORT:-0}" != "1" ]]; then
  VPC_DATA="${N019_VPC_DATA:-$N019_OFFICIAL_DATA/vpc/data}"
  python -m n019.export_vpc_anon \
    --vpc-data-dir "$VPC_DATA" \
    --anon-manifest "$OUT/anon.jsonl" \
    --suffix "$SUFFIX" \
    --dataset-name train-clean-360 \
    --overwrite-missing

  COUNT=$(wc -l < "$VPC_DATA/train-clean-360$SUFFIX/wav.scp")
  if [[ "$COUNT" != "104014" ]]; then
    echo "Expected 104014 exported WAVs, got $COUNT" >&2
    exit 1
  fi
fi

echo "LS360_ANONYMISATION_COMPLETE out=$OUT suffix=$SUFFIX"
