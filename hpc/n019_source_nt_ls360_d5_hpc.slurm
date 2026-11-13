#!/usr/bin/env bash
#SBATCH --job-name=n019_source_nt_ls360
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=01:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

OUT="${N019_SOURCE_NT_DIAG_OUT:-$N019_OFFICIAL_RUNS/source_reconstruction_diag_20261112}"
MANIFEST="$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360.jsonl"
MODEL="$N019_OFFICIAL_MODELS/wpro"

mkdir -p "$OUT/embeddings"
echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "purpose=source-reconstruction diagnostic only"
echo "manifest=$MANIFEST"
echo "model=$MODEL"
echo "out=$OUT"

test -f "$MANIFEST"
test -f "$MODEL/model.safetensors"

python -m n019.extract_speakers \
  --manifest "$MANIFEST" \
  --model "$MODEL" \
  --kind nt \
  --level speaker \
  --max-utterances-per-speaker 32 \
  --out "$OUT/embeddings/ls360" \
  --device cuda

python - "$OUT/embeddings/ls360/nt_speaker_embeddings.npz" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

path = Path(sys.argv[1])
with np.load(path, allow_pickle=False) as archive:
    keys = set(archive.files)
    matrix = np.stack([archive[key] for key in sorted(keys)])
if len(keys) != 921:
    raise SystemExit(f"expected 921 source speakers, got {len(keys)}")
if matrix.shape[1:] != (250,):
    raise SystemExit(f"expected 250-D embeddings, got {matrix.shape}")
if not np.isfinite(matrix).all():
    raise SystemExit("non-finite embeddings")
norms = np.linalg.norm(matrix, axis=1)
if not np.allclose(norms, 1.0, atol=1e-4):
    raise SystemExit("embeddings are not unit norm")
print(json.dumps({
    "speakers": len(keys),
    "dimension": 250,
    "norm_min": float(norms.min()),
    "norm_max": float(norms.max()),
    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
}, indent=2, sort_keys=True))
PY

sha256sum "$OUT/embeddings/ls360/nt_speaker_embeddings.npz"
echo "N019_SOURCE_NT_LS360_COMPLETE out=$OUT/embeddings/ls360"
