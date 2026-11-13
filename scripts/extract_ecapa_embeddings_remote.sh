#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh" >/dev/null

MANIFEST="${N019_ECAPA_MANIFEST:-$N019_OFFICIAL_DATA/processed/manifests/libritts_train_clean_100.jsonl}"
MODEL="${N019_ECAPA_MODEL:-$N019_OFFICIAL_MODELS/vpc/exp/asv_orig}"
OUT="${N019_ECAPA_EMBEDDINGS_OUT:-$N019_OFFICIAL_DATA/processed/embeddings/libritts_train_clean_100_ecapa}"
CHECKPOINT_EVERY="${N019_ECAPA_CHECKPOINT_EVERY:-100}"
EXPECTED_SPEAKERS="${N019_ECAPA_EXPECTED_SPEAKERS:-247}"

for required in \
  "$MANIFEST" \
  "$MODEL/hyperparams.yaml" \
  "$MODEL/embedding_model.ckpt" \
  "$MODEL/classifier.ckpt"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing ECAPA embedding input: $required" >&2
    exit 1
  fi
done

mkdir -p "$OUT"
RESUME_FLAG=()
if [[ -f "$OUT/partial_embeddings.npz" ]]; then
  RESUME_FLAG=(--resume)
fi

{
  echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
  echo "scope=ecapa_speaker_embeddings"
  echo "manifest=$MANIFEST"
  echo "model=$MODEL"
  echo "out=$OUT"
  echo "checkpoint_every=$CHECKPOINT_EVERY"
  echo "resume=${#RESUME_FLAG[@]}"
  echo "expected_speakers=$EXPECTED_SPEAKERS"
} | tee "$OUT/launch.txt"

python -u -m n019.extract_speakers \
  --manifest "$MANIFEST" \
  --model "$MODEL" \
  --kind ecapa \
  --level speaker \
  --out "$OUT" \
  --checkpoint-every "$CHECKPOINT_EVERY" \
  --device cuda \
  "${RESUME_FLAG[@]}"

python - "$OUT/ecapa_speaker_embeddings.npz" "$EXPECTED_SPEAKERS" <<'PY'
import sys
import numpy as np

path = sys.argv[1]
expected_speakers = int(sys.argv[2])
archive = np.load(path, allow_pickle=False)
keys = list(archive.files)
dimensions = {int(archive[key].size) for key in keys}
finite = all(bool(np.isfinite(archive[key]).all()) for key in keys)
archive.close()
if len(keys) != expected_speakers:
    raise SystemExit(
        f"Expected {expected_speakers} ECAPA speakers, got {len(keys)}"
    )
if dimensions != {192}:
    raise SystemExit(f"Expected 192-D ECAPA embeddings, got {dimensions}")
if not finite:
    raise SystemExit("ECAPA embeddings contain non-finite values")
print(
    f"ECAPA_EMBEDDINGS_COMPLETE speakers={len(keys)} "
    f"dimension=192 manifest={sys.argv[1]}"
)
PY
