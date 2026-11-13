#!/bin/bash
#SBATCH --job-name=n019_tutt1918_hpc
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=01:00:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

MANIFEST="${N019_TARGET_UTTERANCE_MANIFEST:?Set N019_TARGET_UTTERANCE_MANIFEST}"
OUT="${N019_TARGET_UTTERANCE_OUT:?Set N019_TARGET_UTTERANCE_OUT}"
MODEL="$N019_OFFICIAL_MODELS/wpro"
EXPECTED_ROWS="${N019_TARGET_UTTERANCE_EXPECTED_ROWS:-1918}"
EXPECTED_SPEAKERS="${N019_TARGET_UTTERANCE_EXPECTED_SPEAKERS:-954}"

test -f "$MANIFEST"
test -f "$MODEL/spk_embeddings.py"

python - "$MANIFEST" "$EXPECTED_ROWS" "$EXPECTED_SPEAKERS" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected_rows = int(sys.argv[2])
expected_speakers = int(sys.argv[3])
ids = []
speakers = set()
for line in path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    row = json.loads(line)
    ids.append(str(row.get("id") or row.get("utterance_id")))
    speakers.add(str(row["speaker"]))
if len(ids) != expected_rows or len(set(ids)) != expected_rows:
    raise SystemExit(f"bad target utterance IDs: {len(ids)}")
if len(speakers) != expected_speakers:
    raise SystemExit(
        f"expected {expected_speakers} speakers, got {len(speakers)}"
    )
print(f"target_utterance_manifest_ok rows={len(ids)} speakers={len(speakers)}")
PY

echo "user=$(id -un) host=$(hostname) date=$(date -Is) job=${SLURM_JOB_ID}"
echo "manifest=$MANIFEST"
echo "out=$OUT"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

mkdir -p "$OUT"
python -u -m n019.extract_speakers \
  --manifest "$MANIFEST" \
  --model "$MODEL" \
  --kind nt \
  --level utterance \
  --checkpoint-every 200 \
  --resume \
  --device cuda \
  --out "$OUT"

sha256sum "$OUT/nt_utterance_embeddings.npz" "$OUT/metadata.json"
echo "N019_TARGET_UTTERANCE_HPC_COMPLETE out=$OUT"
