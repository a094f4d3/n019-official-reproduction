#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

WORK="/dev/shm/n019_res075_durextra05_${SLURM_JOB_ID:-manual}"
VPC_ROOT="$WORK/vpc"
OUT="$WORK/test"
VPC_SOURCE="$N019_OFFICIAL_DATA/vpc/data"
LABEL=ntecres0p75_durextra0p5_20261118
SUFFIX="_n019_${LABEL}"

mkdir -p "$VPC_ROOT/data/libri_test"
ln -sfn "$VPC_SOURCE/libri_test/wav" "$VPC_ROOT/data/libri_test/wav"

export N019_DATA_SUFFIX="$SUFFIX"
export N019_VPC_DATA="$VPC_ROOT"
export N019_WNT_BASE_VPC_DATA="$VPC_ROOT"
export N019_WNT_ATTACKS="I L"
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$OUT/wnt_il"

bash "$ROOT/scripts/evaluate_wnt_remote.sh"

python - "$OUT/eval" "$OUT/wnt_il" "$WORK/assets/residual_0p75.npz" \
  "$OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

eval_out = Path(sys.argv[1])
wnt_out = Path(sys.argv[2])
destination = Path(sys.argv[4])
quality = json.loads((eval_out / "quality_metrics.json").read_text(encoding="utf-8"))
wnt = json.loads((wnt_out / "summary.json").read_text(encoding="utf-8"))
result = {
    "residual_strength": 0.75,
    "duration_extrapolation": 0.5,
    "preserve_predicted_total": True,
    "target_embeddings": sys.argv[3],
    "quality": quality["values"],
    "paper_quality": {"WER": 7.41, "UTMOS": 3.63, "WhiSQA": 3.69},
    "wnt_I": float(wnt["attacks"]["I"]["mean_eer_percent"]),
    "wnt_L": float(wnt["attacks"]["L"]["mean_eer_percent"]),
    "paper_wnt_I": 39.9,
    "paper_wnt_L": 42.3,
}
destination.write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$WORK/assets/residual_0p75.npz" \
  "$OUT/anonymised/anon.jsonl" \
  "$OUT/eval/quality_metrics.json" \
  "$OUT/wnt_il/summary.json" \
  "$OUT/summary.json"
echo "N019_RESIDUAL075_DUREXTRA05_WNT_RETRY_COMPLETE out=$OUT"
