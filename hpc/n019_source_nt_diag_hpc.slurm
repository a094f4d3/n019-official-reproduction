#!/usr/bin/env bash
#SBATCH --job-name=n019_source_nt_diag
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=01:00:00
#SBATCH --exclude=f11r1n01,f11r2n13
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

OUT="${N019_SOURCE_NT_DIAG_OUT:-$N019_OFFICIAL_RUNS/source_reconstruction_diag_20261112}"
TEST_MANIFEST="$N019_OFFICIAL_DATA/processed/manifests/libri_test.jsonl"
LS360_MANIFEST="$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360.jsonl"
MODEL="$N019_OFFICIAL_MODELS/wpro"

mkdir -p "$OUT/embeddings" "$OUT/target_maps"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "purpose=source-reconstruction diagnostic only"
echo "model=$MODEL"
echo "test_manifest=$TEST_MANIFEST"
echo "ls360_manifest=$LS360_MANIFEST"
echo "out=$OUT"

python -m n019.extract_speakers \
  --manifest "$TEST_MANIFEST" \
  --model "$MODEL" \
  --kind nt \
  --level speaker \
  --max-utterances-per-speaker 32 \
  --out "$OUT/embeddings/test" \
  --device cuda

python -m n019.extract_speakers \
  --manifest "$LS360_MANIFEST" \
  --model "$MODEL" \
  --kind nt \
  --level speaker \
  --max-utterances-per-speaker 32 \
  --out "$OUT/embeddings/ls360" \
  --device cuda

python "$ROOT/scripts/make_source_reconstruction_target_map.py" \
  --source-manifest "$TEST_MANIFEST" \
  --out "$OUT/target_maps/libri_test_source_target_map.jsonl" \
  --metadata "$OUT/target_maps/libri_test_source_target_map.metadata.json"

python "$ROOT/scripts/make_source_reconstruction_target_map.py" \
  --source-manifest "$LS360_MANIFEST" \
  --out "$OUT/target_maps/ls360_source_target_map.jsonl" \
  --metadata "$OUT/target_maps/ls360_source_target_map.metadata.json"

python - "$OUT" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

root = Path(sys.argv[1])
checks = {}
map_metadata = {
    "test": root / "target_maps/libri_test_source_target_map.metadata.json",
    "ls360": root / "target_maps/ls360_source_target_map.metadata.json",
}
for name, metadata_path in map_metadata.items():
    expected = int(
        json.loads(metadata_path.read_text(encoding="utf-8"))["speakers"]
    )
    path = root / "embeddings" / name / "nt_speaker_embeddings.npz"
    with np.load(path, allow_pickle=False) as archive:
        keys = set(archive.files)
        matrix = np.stack([archive[key] for key in sorted(keys)])
    if len(keys) != expected:
        raise SystemExit(f"{name}: expected {expected} speakers, got {len(keys)}")
    if matrix.shape[1:] != (250,):
        raise SystemExit(f"{name}: expected 250-D embeddings")
    if not np.isfinite(matrix).all():
        raise SystemExit(f"{name}: non-finite embeddings")
    norms = np.linalg.norm(matrix, axis=1)
    if not np.allclose(norms, 1.0, atol=1e-4):
        raise SystemExit(f"{name}: embeddings are not unit norm")
    checks[name] = {
        "speakers": len(keys),
        "npz": str(path),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "norm_min": float(norms.min()),
        "norm_max": float(norms.max()),
    }

(root / "verification.json").write_text(
    json.dumps(checks, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(checks, indent=2, sort_keys=True))
PY

sha256sum \
  "$OUT/embeddings/test/nt_speaker_embeddings.npz" \
  "$OUT/embeddings/ls360/nt_speaker_embeddings.npz" \
  "$OUT/target_maps/libri_test_source_target_map.jsonl" \
  "$OUT/target_maps/ls360_source_target_map.jsonl" \
  "$OUT/verification.json"

echo "N019_SOURCE_NT_DIAG_COMPLETE out=$OUT"
