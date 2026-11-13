#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SUFFIX="${N019_DATA_SUFFIX:-_n019_pilot}"
RUN_NAME="${N019_RUN_NAME:-pilot_e2e}"
OUT="$N019_OFFICIAL_RUNS/$RUN_NAME"
ANON="$OUT/anonymised/DU-pred-nt"
VOCODER="${N019_VOCODER:-$N019_OFFICIAL_RUNS/vocoder_nt_pilot_1020953/last.pt}"
DURATION="${N019_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_pred_main/best.pt}"
SOURCE="$N019_OFFICIAL_DATA/processed/manifests/libri_test.jsonl"
UNITS="$N019_OFFICIAL_DATA/processed/units/libri_test/unit_records.jsonl"
TARGET_MAP="$N019_OFFICIAL_DATA/processed/targets/target_map.jsonl"
TARGET_EMB="$N019_OFFICIAL_DATA/processed/embeddings/libri_test_target_nt_utterance/nt_utterance_embeddings.npz"

for required in \
  "$VOCODER" \
  "$DURATION" \
  "$SOURCE" \
  "$UNITS" \
  "$TARGET_MAP" \
  "$TARGET_EMB"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing pilot input: $required" >&2
    exit 1
  fi
done

mkdir -p "$OUT"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "date=$(date -Is)"
  echo "scope=pilot_e2e_not_table1"
  echo "suffix=$SUFFIX"
  echo "vocoder=$VOCODER"
  echo "duration=$DURATION"
  echo "out=$OUT"
} | tee "$OUT/launch.txt"

RESUME_FLAG=()
if [[ -f "$ANON/anon.partial.jsonl" ]]; then
  RESUME_FLAG=(--resume)
fi

python -u -m n019.anonymize \
  --source-manifest "$SOURCE" \
  --unit-records "$UNITS" \
  --target-map "$TARGET_MAP" \
  --duration-mode pred \
  --duration-model "$DURATION" \
  --vocoder "$VOCODER" \
  --vocoder-type nt \
  --vocoder-embeddings "$TARGET_EMB" \
  --out-dir "$ANON" \
  --device cuda \
  "${RESUME_FLAG[@]}"

python -m n019.export_vpc_anon \
  --vpc-data-dir "$N019_OFFICIAL_DATA/vpc/data" \
  --anon-manifest "$ANON/anon.jsonl" \
  --suffix "$SUFFIX" \
  --dataset-name libri_test \
  --dataset-name libri_test_enrolls \
  --dataset-name libri_test_trials_f \
  --dataset-name libri_test_trials_m \
  --overwrite-missing

N019_DATA_SUFFIX="$SUFFIX" \
N019_RUN_NAME="$RUN_NAME" \
  bash "$ROOT/scripts/evaluate_evpc_pre_remote.sh"

N019_DATA_SUFFIX="$SUFFIX" \
N019_RUN_NAME="$RUN_NAME" \
N019_WNT_ATTACKS="I L" \
  bash "$ROOT/scripts/evaluate_wnt_remote.sh"

EVAL_ROOT="$N019_OFFICIAL_RUNS/eval/$RUN_NAME"
python -m n019.collect_metrics \
  --run-dir "$OUT" \
  --out "$OUT/anonymisation_summary.json" >/dev/null
python -m n019.collect_metrics \
  --run-dir "$EVAL_ROOT" \
  --out "$OUT/eval_metrics_summary.json" >/dev/null

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
anonymisation = json.loads(
    (out / "anonymisation_summary.json").read_text(encoding="utf-8")
)
evaluation = json.loads(
    (out / "eval_metrics_summary.json").read_text(encoding="utf-8")
)
combined = {"anonymisation": anonymisation, "evaluation": evaluation}
(out / "pilot_metrics_summary.json").write_text(
    json.dumps(combined, indent=2) + "\n",
    encoding="utf-8",
)
PY

echo "PILOT_E2E_COMPLETE out=$OUT suffix=$SUFFIX"
