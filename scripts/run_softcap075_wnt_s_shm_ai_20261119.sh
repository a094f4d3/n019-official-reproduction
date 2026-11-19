#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
VOICE_ROOT=/public/home/a094f4d10/voice_projects
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="$VOICE_ROOT"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SOURCE_ROOT="$N019_OFFICIAL_RUNS/privacy/softcap075_full_s_hpc_20261119"
PUBLIC_OUT="$N019_OFFICIAL_RUNS/privacy/softcap075_wnt_s_shm_20261119"
WORK="/dev/shm/n019_softcap075_wnt_s_shm_$(date +%s)_$$"
AUDIO_SRC="$SOURCE_ROOT/anonymised_ls360"
TRAIN_SRC="$SOURCE_ROOT/vpc/train-clean-360_n019_softcap075_recovery_20261119"
SUFFIX=_n019_softcap075_recovery_20261119
BASE_VPC_DATA="$N019_OFFICIAL_DATA/vpc_ai/data"

mkdir -p "$WORK/audio" "$WORK/train" "$PUBLIC_OUT"
exec >>"$PUBLIC_OUT/run.log" 2>&1
set -x
export TMPDIR="$WORK/tmp"

test -d "$AUDIO_SRC"
test -s "$TRAIN_SRC/wav.scp"
test -s "$TRAIN_SRC/utt2spk"
test -s "$BASE_VPC_DATA/libri_test_trials_f/trials"
test -s "$BASE_VPC_DATA/libri_test_trials_m/trials"

echo "ai_task=${MARSV2_TASK_ID:-manual} host=$(hostname) date=$(date -Is)"
echo "purpose=softcap075 W-NT S with /dev/shm audio cache"
echo "source=$SOURCE_ROOT"
echo "public_out=$PUBLIC_OUT"
echo "resources=1 DCU 15 CPU 59GB wall=3h expected=2.2 worst=3.0"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

# The AI worker's NFS path is much slower for random 100k-file reads.  Cache
# the anonymised LS360 WAV tree in tmpfs before starting the attacker.
cp -a "$AUDIO_SRC/." "$WORK/audio/"
cp "$TRAIN_SRC/utt2spk" "$WORK/train/utt2spk"
python - "$TRAIN_SRC/wav.scp" "$WORK/train/wav.scp" \
  "$AUDIO_SRC" "$WORK/audio" <<'PY'
import sys
from pathlib import Path

source_scp = Path(sys.argv[1])
destination = Path(sys.argv[2])
source_root = sys.argv[3].rstrip("/")
destination_root = sys.argv[4].rstrip("/")

rows = []
with source_scp.open(encoding="utf-8") as handle:
    for line_number, raw in enumerate(handle, 1):
        fields = raw.rstrip("\n").split(maxsplit=1)
        if len(fields) != 2:
            raise ValueError(f"invalid wav.scp row {line_number}")
        utterance_id, audio = fields
        if not audio.startswith(source_root + "/"):
            raise ValueError(f"unexpected audio root: {audio}")
        rows.append(f"{utterance_id} {destination_root}/{audio[len(source_root)+1:]}")
destination.write_text("\n".join(rows) + "\n", encoding="utf-8")
print(f"rewritten_wav_scp_rows={len(rows)}")
PY

export N019_VPC_DATA="$WORK"
export N019_DATA_SUFFIX=_n019
export N019_WNT_S_RUN_NAME=softcap075_wnt_s_shm
export N019_WNT_S_OUT="$WORK/wnt_s_train"
export N019_WNT_BASE_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_NPROC=1
export N019_WNT_S_TOTAL_BATCH=16
export N019_WNT_S_WORKERS=8
export N019_WNT_S_EPOCHS=4
export N019_WNT_S_MAX_HOURS=2.0
export N019_WNT_S_LR=1e-4
export N019_WNT_S_HEAD_LR=1e-3
export N019_WNT_S_FREEZE_WAVLM=1
export N019_WNT_S_AAM_MARGIN=0.05
export N019_WNT_S_AAM_SCALE=10
export N019_WNT_S_RESET_SCHEDULER=0

# train_wnt_s_remote.sh resolves DATA as $N019_VPC_DATA/train-clean-360$SUFFIX.
mv "$WORK/train" "$WORK/train-clean-360_n019"
bash "$ROOT/scripts/train_wnt_s_remote.sh"

WNT_S_MODEL="$WORK/wnt_s_train/model"
test -s "$WNT_S_MODEL/model.safetensors"

export N019_VPC_DATA="$SOURCE_ROOT/vpc"
export N019_DATA_SUFFIX="$SUFFIX"
export N019_WNT_BASE_VPC_DATA="$BASE_VPC_DATA"
export N019_WNT_S_MODEL="$WNT_S_MODEL"
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_ATTACKS=S
export N019_WNT_OUT="$WORK/wnt_s_eval"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"

python - "$WORK/wnt_s_eval/summary.json" "$PUBLIC_OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

wnt = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
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

mkdir -p "$PUBLIC_OUT/wnt_s_model"
cp -a "$WNT_S_MODEL/." "$PUBLIC_OUT/wnt_s_model/"
cp "$WORK/wnt_s_eval/summary.json" "$PUBLIC_OUT/wnt_s_summary.json"
sha256sum \
  "$PUBLIC_OUT/summary.json" \
  "$PUBLIC_OUT/wnt_s_summary.json" \
  "$PUBLIC_OUT/wnt_s_model/model.safetensors" \
  > "$PUBLIC_OUT/SHA256SUMS.txt"
chown -R 666505:666505 "$PUBLIC_OUT"
echo "N019_SOFTCAP075_WNT_S_SHM_COMPLETE out=$PUBLIC_OUT"
