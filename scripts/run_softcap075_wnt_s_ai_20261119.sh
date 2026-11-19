#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
VOICE_ROOT=/public/home/a094f4d10/voice_projects
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="$VOICE_ROOT"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SOURCE_ROOT="$N019_OFFICIAL_RUNS/privacy/softcap075_full_s_hpc_20261119"
VPC_DATA="$SOURCE_ROOT/vpc"
BASE_VPC_DATA="$N019_OFFICIAL_DATA/vpc_ai/data"
SUFFIX=_n019_softcap075_recovery_20261119
PUBLIC_OUT="$N019_OFFICIAL_RUNS/privacy/softcap075_wnt_s_ai_20261119"
WORK="/dev/shm/n019_softcap075_wnt_s_$(date +%s)_$$"

mkdir -p "$WORK/tmp" "$PUBLIC_OUT"
exec >>"$PUBLIC_OUT/run.log" 2>&1
set -x
export TMPDIR="$WORK/tmp"

for required in \
  "$VPC_DATA/train-clean-360$SUFFIX/wav.scp" \
  "$VPC_DATA/train-clean-360$SUFFIX/utt2spk" \
  "$VPC_DATA/libri_test_enrolls$SUFFIX/wav.scp" \
  "$VPC_DATA/libri_test_trials_f$SUFFIX/wav.scp" \
  "$VPC_DATA/libri_test_trials_m$SUFFIX/wav.scp" \
  "$BASE_VPC_DATA/libri_test_trials_f/trials" \
  "$BASE_VPC_DATA/libri_test_trials_m/trials" \
  "$N019_OFFICIAL_MODELS/wpro/config.json" \
  "$N019_OFFICIAL_MODELS/wpro/model.safetensors" \
  "$N019_OFFICIAL_MODELS/wpro/spk_embeddings.py"; do
  test -s "$required" || {
    echo "Missing W-NT S input: $required" >&2
    exit 1
  }
done

echo "ai_task=${MARSV2_TASK_ID:-manual} host=$(hostname) date=$(date -Is)"
echo "suffix=$SUFFIX"
echo "vpc_data=$VPC_DATA"
echo "public_out=$PUBLIC_OUT"
echo "resources=1 DCU 15 CPU 59GB wall=2h expected=1.5 worst=2.0"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

export N019_VPC_DATA="$VPC_DATA"
export N019_DATA_SUFFIX="$SUFFIX"
export N019_WNT_S_RUN_NAME=n019_softcap075_wnt_s
export N019_WNT_S_OUT="$WORK/wnt_s_train"
export N019_WNT_BASE_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_NPROC=1
export N019_WNT_S_TOTAL_BATCH=16
export N019_WNT_S_WORKERS=0
export N019_WNT_S_EPOCHS=4
export N019_WNT_S_MAX_HOURS=1.5
export N019_WNT_S_LR=1e-4
export N019_WNT_S_HEAD_LR=1e-3
export N019_WNT_S_FREEZE_WAVLM=1
export N019_WNT_S_AAM_MARGIN=0.05
export N019_WNT_S_AAM_SCALE=10
export N019_WNT_S_RESET_SCHEDULER=0
bash "$ROOT/scripts/train_wnt_s_remote.sh"

WNT_S_MODEL="$(
  find "$WORK/wnt_s_train/snapshots" -maxdepth 1 -type d -name 'epoch*_model' \
    | sort -V | tail -n 1
)"
test -n "$WNT_S_MODEL"
test -s "$WNT_S_MODEL/model.safetensors"

export N019_WNT_S_MODEL="$WNT_S_MODEL"
export N019_WNT_ATTACKS=S
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_BASE_VPC_DATA="$BASE_VPC_DATA"
export N019_WNT_OUT="$WORK/wnt_s_eval"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"

python - "$WORK" "$PUBLIC_OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

work = Path(sys.argv[1])
wnt = json.loads((work / "wnt_s_eval" / "summary.json").read_text())
result = {
    "condition": "residual0.5_duration0.5_softcap0.75",
    "suffix": "_n019_softcap075_recovery_20261119",
    "W_NT_S": wnt["attacks"]["S"],
    "paper_W_NT_S": 24.6,
}
Path(sys.argv[2]).write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

cp "$WORK/wnt_s_eval/summary.json" "$PUBLIC_OUT/wnt_s_summary.json"
mkdir -p "$PUBLIC_OUT/wnt_s_model"
cp -a "$WNT_S_MODEL/." "$PUBLIC_OUT/wnt_s_model/"
sha256sum \
  "$PUBLIC_OUT/summary.json" \
  "$PUBLIC_OUT/wnt_s_summary.json" \
  "$PUBLIC_OUT/wnt_s_model/model.safetensors" \
  > "$PUBLIC_OUT/SHA256SUMS.txt"
chown -R 666505:666505 "$PUBLIC_OUT"
echo "N019_SOFTCAP075_WNT_S_COMPLETE out=$PUBLIC_OUT"
