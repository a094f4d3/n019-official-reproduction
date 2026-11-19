#!/usr/bin/env bash

set -euo pipefail

PUBLIC_ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
DATA_ROOT=/dev/shm/n019_res05_dur065_s_1159221
RETRY="/dev/shm/n019_res05_dur065_s_retry_${SLURM_JOB_ID:-manual}"
CODE="$RETRY/code"
TRAIN_FILE="$CODE/vendor/Voice-Privacy-Challenge-2024/evaluation/privacy/asv/asv_train/train_speaker_embeddings.py"

test -s "$DATA_ROOT/vpc/train-clean-360_n019_n019_res05_dur065_20261118/wav.scp"
test -s "$DATA_ROOT/vpc/libri_test_enrolls_n019_n019_res05_dur065_20261118/wav.scp"
test -s "$PUBLIC_ROOT/scripts/run_s_eval_remote.sh"

mkdir -p "$RETRY/tmp" "$RETRY/miopen" "$RETRY/logs" "$RETRY/runs"
cp -a "$PUBLIC_ROOT" "$CODE"

python - "$TRAIN_FILE" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = """    # Training
    speaker_brain.fit(
        speaker_brain.hparams.epoch_counter,
        train_data,
        valid_data,
        train_loader_kwargs=hparams["dataloader_options"],
        valid_loader_kwargs=hparams["dataloader_options"],
    )
"""
new = """    # BatchNorm in ECAPA rejects a final training batch of size one.
    train_loader_kwargs = dict(hparams["dataloader_options"])
    train_loader_kwargs["drop_last"] = True

    # Training
    speaker_brain.fit(
        speaker_brain.hparams.epoch_counter,
        train_data,
        valid_data,
        train_loader_kwargs=train_loader_kwargs,
        valid_loader_kwargs=hparams["dataloader_options"],
    )
"""
if old not in text:
    raise SystemExit("Expected training block was not found")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY

export N019_OFFICIAL_ROOT="$CODE"
source "$CODE/hpc/activate_n019_official.sh"
cd "$CODE"
export TMPDIR="$RETRY/tmp"
export N019_OFFICIAL_LOGS="$RETRY/logs"
export N019_OFFICIAL_RUNS="$RETRY/runs"
export MIOPEN_USER_DB_PATH="$RETRY/miopen"
export MIOPEN_CUSTOM_CACHE_DIR="$RETRY/miopen"

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=S-only retry for residual0.5 duration0.65 after final-batch BatchNorm failure"
echo "source_data=$DATA_ROOT"
echo "retry=$RETRY"
echo "fix=train DataLoader drop_last=true; MIOpen cache redirected to /dev/shm"

bash "$CODE/scripts/gpu_tiny_matmul_watchdog.sh"

N019_VPC_DATA="$DATA_ROOT/vpc" \
N019_DATA_SUFFIX="_n019_n019_res05_dur065_20261118" \
N019_RUN_NAME="n019_res05_dur065_retry" \
N019_S_EVAL_OUT="$RETRY/s_eval" \
  bash "$CODE/scripts/run_s_eval_remote.sh"

python - "$RETRY/s_eval/s_metrics.json" "$RETRY/summary.json" <<'PY'
import json
import sys
from pathlib import Path

metrics = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
result = {
    "system": "DU-pred-nt residual0.5 duration0.65",
    "paper_E_VPC_S": 34.8,
    "formal_E_VPC_S": 29.7425,
    "residual0.5_duration0.5_E_VPC_S": 33.255,
    "s_metrics": metrics,
}
Path(sys.argv[2]).write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum "$RETRY/s_eval/s_metrics.json" "$RETRY/summary.json"
echo "N019_RES05_DUR065_S_RETRY_COMPLETE retry=$RETRY"
echo "Holding /dev/shm for recovery"
sleep 7200
