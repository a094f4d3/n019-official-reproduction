#!/bin/bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
cd "$ROOT"
source "$ROOT/hpc/activate_n019_official.sh"

WAIT_JOB="${1:-1148911}"
RECORD="$HOME/voice_projects/runs/n019_official/cross_speaker_pipeline_submission_20261117.json"
TRAIN_OUT="$HOME/voice_projects/runs/n019_official/vocoder_nt_crossspeaker_ft_20261117"

if [[ ! "$WAIT_JOB" =~ ^[0-9]+$ ]]; then
  echo "Wait JobID must be numeric: $WAIT_JOB" >&2
  exit 1
fi
if [[ -e "$RECORD" ]]; then
  echo "Refusing duplicate submission; record exists: $RECORD" >&2
  cat "$RECORD" >&2
  exit 1
fi
if [[ -e "$TRAIN_OUT/last.pt" ]]; then
  echo "Refusing to overwrite training checkpoint: $TRAIN_OUT/last.pt" >&2
  exit 1
fi

mkdir -p "$(dirname "$RECORD")"
TRAIN_JOB="$(sbatch --parsable --dependency="afterany:$WAIT_JOB" \
  "$ROOT/hpc/n019_cross_speaker_ft_d10_hpc.slurm")"
SELECTOR_JOB="$(sbatch --parsable --dependency="afterany:$TRAIN_JOB" \
  "$ROOT/hpc/n019_cross_speaker_select_d10_hpc.slurm")"
DIAGNOSTIC_JOB="$(sbatch --parsable --dependency="afterany:$SELECTOR_JOB" \
  "$ROOT/hpc/n019_cross_speaker_privacy_diag_d10_hpc.slurm")"

python - "$RECORD" "$WAIT_JOB" "$TRAIN_JOB" "$SELECTOR_JOB" "$DIAGNOSTIC_JOB" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

destination = Path(sys.argv[1])
record = {
    "created_utc": datetime.now(timezone.utc).isoformat(),
    "account": "a094f4d10",
    "mode": "hpc_slurm",
    "dependency_root": sys.argv[2],
    "training_job": sys.argv[3],
    "selection_job": sys.argv[4],
    "privacy_diagnostic_job": sys.argv[5],
    "training_resources": "1 DCU, 16 CPU / 60 GB, 2 h",
    "training_expected_card_hours": 0.8,
    "training_worst_card_hours": 2.0,
    "selection_resources": "1 DCU, 16 CPU / 60 GB, 2 h",
    "selection_expected_card_hours": 0.6,
    "selection_worst_card_hours": 2.0,
    "privacy_diagnostic_resources": "1 DCU, 16 CPU / 60 GB, 1 h",
    "privacy_diagnostic_expected_card_hours": 0.2,
    "privacy_diagnostic_worst_card_hours": 1.0,
    "stop_conditions": [
        "watchdog failure",
        "non-finite loss",
        "missing or mismatched input SHA256",
        "wall-clock expiry",
        "no dev snapshot passes the quality gate",
    ],
}
destination.write_text(
    json.dumps(record, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(record, indent=2, sort_keys=True))
PY

sha256sum "$RECORD"
