#!/bin/bash
#SBATCH --job-name=n019_tspkfull_hpc
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=06:00:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

MANIFEST="${N019_TARGET_FULLMEAN_MANIFEST:-$N019_OFFICIAL_DATA/processed/targets/target_speaker_full843_other500.jsonl}"
OUT="${N019_TARGET_FULLMEAN_OUT:-$N019_OFFICIAL_DATA/processed/embeddings/target_speaker_fullmean843_hpc_20261109}"
MODEL="$N019_OFFICIAL_MODELS/wpro"
EXPECTED_ROWS="${N019_TARGET_FULLMEAN_EXPECTED_ROWS:-168023}"
EXPECTED_SPEAKERS="${N019_TARGET_FULLMEAN_EXPECTED_SPEAKERS:-843}"
EXPECTED_GROUP_MIN="${N019_TARGET_FULLMEAN_EXPECTED_GROUP_MIN:-8}"
EXPECTED_GROUP_MAX="${N019_TARGET_FULLMEAN_EXPECTED_GROUP_MAX:-815}"

test -f "$MANIFEST"
test -f "$MODEL/spk_embeddings.py"

python - \
  "$MANIFEST" \
  "$EXPECTED_ROWS" \
  "$EXPECTED_SPEAKERS" \
  "$EXPECTED_GROUP_MIN" \
  "$EXPECTED_GROUP_MAX" <<'PY'
import json
import sys
from collections import Counter
from pathlib import Path

path = Path(sys.argv[1])
expected_rows = int(sys.argv[2])
expected_speakers = int(sys.argv[3])
expected_group_min = int(sys.argv[4])
expected_group_max = int(sys.argv[5])
ids = []
counts = Counter()
with path.open(encoding="utf-8") as handle:
    for line in handle:
        if not line.strip():
            continue
        row = json.loads(line)
        ids.append(str(row.get("id") or row.get("utterance_id")))
        counts[str(row["speaker"])] += 1
if len(ids) != expected_rows:
    raise SystemExit(f"expected {expected_rows} rows, got {len(ids)}")
if len(ids) != len(set(ids)):
    raise SystemExit("duplicate target utterance IDs")
if len(counts) != expected_speakers:
    raise SystemExit(
        f"expected {expected_speakers} speakers, got {len(counts)}"
    )
if min(counts.values()) != expected_group_min:
    raise SystemExit(
        f"unexpected group min {min(counts.values())}, "
        f"expected {expected_group_min}"
    )
if max(counts.values()) != expected_group_max:
    raise SystemExit(
        f"unexpected group max {max(counts.values())}, "
        f"expected {expected_group_max}"
    )
print(
    "target_fullmean_manifest_ok "
    f"rows={len(ids)} speakers={len(counts)} "
    f"group_min={min(counts.values())} group_max={max(counts.values())}"
)
PY

echo "user=$(id -un) host=$(hostname) date=$(date -Is) job=${SLURM_JOB_ID}"
echo "manifest=$MANIFEST"
echo "out=$OUT"
hy-smi || true

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
  --level speaker \
  --checkpoint-every 1000 \
  --resume \
  --device cuda \
  --out "$OUT"

sha256sum "$OUT/nt_speaker_embeddings.npz" "$OUT/metadata.json"
echo "N019_TARGET_SPEAKER_FULLMEAN_HPC_COMPLETE out=$OUT"
