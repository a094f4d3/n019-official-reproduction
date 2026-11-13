#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SUFFIX="${N019_DATA_SUFFIX:-_n019}"
RUN_NAME="${N019_RUN_NAME:-du_s_eval}"
OUT="${N019_S_EVAL_OUT:-$N019_OFFICIAL_RUNS/eval/$RUN_NAME}"
VPC_DATA="${N019_VPC_DATA:-$N019_OFFICIAL_DATA/vpc/data}"
VENDOR="$ROOT/vendor/Voice-Privacy-Challenge-2024"
CONFIG="${N019_ASV_CONFIG:-$ROOT/configs/eval_paper_test_only_post.yaml}"

for required in \
  "$VPC_DATA/train-clean-360$SUFFIX/wav.scp" \
  "$VPC_DATA/libri_test_enrolls$SUFFIX/wav.scp" \
  "$VPC_DATA/libri_test_trials_f$SUFFIX/wav.scp" \
  "$VPC_DATA/libri_test_trials_m$SUFFIX/wav.scp" \
  "$VENDOR/run_evaluation.py" \
  "$CONFIG"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing required S-evaluation input: $required" >&2
    exit 1
  fi
done

mkdir -p "$OUT"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "user=$(id -un)"
  echo "date=$(date -Is)"
  echo "suffix=$SUFFIX"
  echo "vpc_data=$VPC_DATA"
  echo "out=$OUT"
  python -c "import torch; print('torch=' + torch.__version__); print('hip=' + str(torch.version.hip)); print('dcu_available=' + str(torch.cuda.is_available()))"
} | tee "$OUT/launch.txt"

if ! python -c "import torch; raise SystemExit(0 if torch.cuda.is_available() else 1)"; then
  echo "The official ASV retraining requires a DCU compute-node allocation" >&2
  exit 1
fi

# This is the official VPC2024 eval_post path: train ECAPA on anonymised
# train-clean-360 for 10 epochs, then evaluate the AA trial condition.
overrides=$(python - "$VPC_DATA" "$OUT/exp" "$SUFFIX" <<'PY'
import json
import sys

data_dir, exp_dir, suffix = sys.argv[1:]
print(json.dumps({
    "data_dir": data_dir,
    "exp_dir": exp_dir,
    "anon_data_suffix": suffix,
    "results_summary_path": (
        f"{exp_dir}/results_summary/eval_anon{suffix}/results_anon.txt"
    ),
}))
PY
)

cd "$VENDOR"
set +e
N019_SKIP_DEPENDENCY_CHECK=1 \
  python -u run_evaluation.py \
    --config "$CONFIG" \
    --overwrite "$overrides" \
    2>&1 | tee "$OUT/eval_post.log"
eval_status=${PIPESTATUS[0]}
set -e

RESULTS="$OUT/exp/results_summary/eval_anon$SUFFIX/results_anon.txt"
if [[ "$eval_status" -ne 0 ]]; then
  # Some SCNet DTK builds abort in MIOpen teardown after all scores have
  # already been written. Preserve that valid result, but never mask a
  # failure that occurred before the six official EER rows were emitted.
  if [[ -s "$RESULTS" ]] && [[ "$(wc -l < "$RESULTS")" -eq 6 ]]; then
    echo "WARNING: VPC exited $eval_status after writing complete results" >&2
  else
    exit "$eval_status"
  fi
fi

python -m n019.parse_vpc_results \
  --input "$RESULTS" \
  --results-csv "$OUT/exp/asv_anon$SUFFIX/results$SUFFIX.csv" \
  --model-role anon \
  --out "$OUT/s_metrics.json"

echo "S_EVAL_COMPLETE out=$OUT"
