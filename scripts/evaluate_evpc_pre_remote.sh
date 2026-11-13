#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SUFFIX="${N019_DATA_SUFFIX:-_n019}"
RUN_NAME="${N019_RUN_NAME:-du_evpc}"
OUT="${N019_EVPC_OUT:-$N019_OFFICIAL_RUNS/eval/$RUN_NAME/evpc}"
VPC_DATA="${N019_VPC_DATA:-$N019_OFFICIAL_DATA/vpc/data}"
VPC_BIND_SOURCE="${N019_VPC_BIND_SOURCE:-$N019_OFFICIAL_DATA/vpc/data}"
VENDOR="$ROOT/vendor/Voice-Privacy-Challenge-2024"
CONFIG="${N019_EVPC_CONFIG:-$ROOT/configs/eval_paper_test_only_pre.yaml}"
ASV_ORIG="$N019_OFFICIAL_MODELS/vpc/exp/asv_orig"
ASR="${N019_VPC_ASR:-$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local}"

if [[ -e "$VENDOR/data" && ! -L "$VENDOR/data" ]]; then
  echo "Refusing to replace real VPC vendor data directory: $VENDOR/data" >&2
  exit 1
fi
ln -sfn "$VPC_BIND_SOURCE" "$VENDOR/data"

for required in \
  "$VPC_DATA/libri_test_enrolls$SUFFIX/wav.scp" \
  "$VPC_DATA/libri_test_trials_f$SUFFIX/wav.scp" \
  "$VPC_DATA/libri_test_trials_m$SUFFIX/wav.scp" \
  "$ASV_ORIG/hyperparams.yaml" \
  "$ASR/hyperparams.yaml" \
  "$VENDOR/run_evaluation.py" \
  "$CONFIG"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing required E-VPC input: $required" >&2
    exit 1
  fi
done

mkdir -p "$OUT/exp"
# The reference model directory contains root-owned score folders from AI
# containers. Evaluate against a job-local copy so the HPC user can write
# cache and score files without mutating the shared model tree.
rm -f "$OUT/exp/asv_orig"
if [[ ! -d "$OUT/exp/asv_orig" ]]; then
  cp -a "$ASV_ORIG" "$OUT/exp/asv_orig"
fi
ln -sfn "$ASR" "$OUT/exp/asr"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "date=$(date -Is)"
  echo "suffix=$SUFFIX"
  echo "vpc_data=$VPC_DATA"
  echo "out=$OUT"
} | tee "$OUT/launch.txt"

overrides=$(python - "$VPC_DATA" "$OUT/exp" "$SUFFIX" <<'PY'
import json
import sys

data_dir, exp_dir, suffix = sys.argv[1:]
print(json.dumps({
    "data_dir": data_dir,
    "exp_dir": exp_dir,
    "anon_data_suffix": suffix,
    "results_summary_path": (
        f"{exp_dir}/results_summary/eval_orig{suffix}/results_orig.txt"
    ),
}))
PY
)

cd "$VENDOR"
export N019_SKIP_DEPENDENCY_CHECK=1
(
  python -u run_evaluation.py \
    --config "$CONFIG" \
    --overwrite "$overrides" \
    2>&1 | tee "$OUT/eval_pre.log"
)

python -m n019.parse_vpc_results \
  --input "$OUT/exp/results_summary/eval_orig$SUFFIX/results_orig.txt" \
  --results-csv "$OUT/exp/asv_orig/results$SUFFIX.csv" \
  --model-role original \
  --out "$OUT/evpc_metrics.json"

echo "EVPC_PRE_COMPLETE out=$OUT"
