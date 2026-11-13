#!/bin/bash
#SBATCH --job-name=n019_ls360_target_pilot
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=40G
#SBATCH --time=00:10:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

SOURCE="$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_manifest.jsonl"
MANIFEST="$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_manifest_256.jsonl"
OUT="$N019_OFFICIAL_RUNS/ls360_target_embedding_pilot_${SLURM_JOB_ID}"

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing target manifest: $SOURCE" >&2
  exit 1
fi
if [[ ! -f "$MANIFEST" ]]; then
  head -n 256 "$SOURCE" > "$MANIFEST.tmp"
  mv "$MANIFEST.tmp" "$MANIFEST"
fi
if [[ "$(wc -l < "$MANIFEST")" != "256" ]]; then
  echo "Pilot manifest must contain 256 rows" >&2
  exit 1
fi

mkdir -p "$OUT"
START=$(date +%s)
{
  echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
  echo "job=${SLURM_JOB_ID} scope=ls360_target_embedding_pilot"
  echo "source=$SOURCE"
  echo "manifest=$MANIFEST rows=256"
  echo "out=$OUT"
  echo "wall_limit=00:10:00"
  hy-smi || true
} | tee "$OUT/launch.txt"

bash "$N019_OFFICIAL_ROOT/scripts/preflight_dcu_remote.sh"

python -u -m n019.extract_speakers \
  --manifest "$MANIFEST" \
  --model "$N019_OFFICIAL_MODELS/wpro" \
  --kind nt \
  --level utterance \
  --checkpoint-every 64 \
  --device cuda \
  --out "$OUT"

END=$(date +%s)
ELAPSED=$((END - START))
python - "$OUT" "$ELAPSED" "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

import numpy as np
import torch

out = Path(sys.argv[1])
elapsed = float(sys.argv[2])
manifest = Path(sys.argv[3])
archive_path = out / "nt_utterance_embeddings.npz"
archive = np.load(archive_path, allow_pickle=False)
values = {
    key: torch.from_numpy(archive[key].astype(np.float32))
    for key in archive.files
}
archive.close()
ids = {
    json.loads(line)["id"]
    for line in manifest.read_text(encoding="utf-8").splitlines()
    if line.strip()
}
if set(values) != ids:
    raise ValueError("Pilot embedding IDs do not match the 256-row manifest")
if any(value.numel() != 250 for value in values.values()):
    raise ValueError("Pilot embedding dimension is not 250")
if any(not bool(torch.isfinite(value).all()) for value in values.values()):
    raise ValueError("Pilot embedding contains non-finite values")
norms = torch.stack([value.norm() for value in values.values()])
if not bool(torch.allclose(norms, torch.ones_like(norms), atol=1e-4)):
    raise ValueError("Pilot embeddings are not L2-normalized")
summary = {
    "rows": len(values),
    "elapsed_seconds_including_model_load": elapsed,
    "utterances_per_second": len(values) / elapsed,
    "projected_seconds_for_81605": 81605 / (len(values) / elapsed),
    "dimension": 250,
    "minimum_norm": float(norms.min()),
    "maximum_norm": float(norms.max()),
    "embeddings_sha256": __import__("hashlib").sha256(
        archive_path.read_bytes()
    ).hexdigest(),
}
(out / "pilot_throughput.json").write_text(
    json.dumps(summary, indent=2) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2))
PY

echo "LS360_TARGET_EMBEDDING_PILOT_COMPLETE out=$OUT"
