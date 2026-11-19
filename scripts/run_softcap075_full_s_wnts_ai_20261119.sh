#!/usr/bin/env bash

set -euo pipefail

PUBLIC_ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$PUBLIC_ROOT/hpc/activate_n019_official.sh"

WORK="/dev/shm/n019_softcap075_full_s_$(date +%s)_$$"
PUBLIC_OUT="$N019_OFFICIAL_RUNS/privacy/softcap075_full_s_wnts_20261119"
VPC_ROOT="$WORK/vpc"
TEST_OUT="$WORK/test"
SHARD_ROOT="$WORK/ls360_shards"
ANON_OUT="$WORK/ls360_anon"
S_EVAL_OUT="$WORK/s_eval"
WNT_S_TRAIN_OUT="$WORK/wnt_s_train"
WNT_S_EVAL_OUT="$WORK/wnt_s_eval"

mkdir -p \
  "$WORK/tmp" "$WORK/units" "$VPC_ROOT" "$TEST_OUT" "$SHARD_ROOT" \
  "$ANON_OUT" "$S_EVAL_OUT" "$WNT_S_TRAIN_OUT" "$WNT_S_EVAL_OUT" \
  "$WORK/logs" "$WORK/runs" "$WORK/miopen" "$PUBLIC_OUT"
exec >>"$PUBLIC_OUT/run.log" 2>&1
set -x
export TMPDIR="$WORK/tmp"

cp -a "$PUBLIC_ROOT" "$WORK/code"
ROOT="$WORK/code"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_OFFICIAL_LOGS="$WORK/logs"
export N019_OFFICIAL_RUNS="$WORK/runs"
export MIOPEN_USER_DB_PATH="$WORK/miopen"
export MIOPEN_CUSTOM_CACHE_DIR="$WORK/miopen"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

cp -a "$N019_OFFICIAL_DATA/vpc_ai/data/." "$VPC_ROOT/"
rm -rf "$VPC_ROOT/train-clean-360"
mkdir -p "$VPC_ROOT/train-clean-360"
cp -a "$N019_OFFICIAL_DATA/vpc/data/train-clean-360/." \
  "$VPC_ROOT/train-clean-360/"

python - "$ROOT/vendor/Voice-Privacy-Challenge-2024/evaluation/privacy/asv/asv_train/train_speaker_embeddings.py" <<'PY'
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

BUNDLE="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117"
TEST_SOURCE="$BUNDLE/units/unit_records.jsonl"
TEST_TARGET_MAP="$BUNDLE/target_map.jsonl"
VOCODER="$BUNDLE/assets/generator_soup2.pt"
DURATION_MODEL="$BUNDLE/assets/duration_pred_paperfix_best.pt"
TARGET_TEST="$N019_OFFICIAL_DATA/processed/embeddings/nt_ecapa_residual_test_20261117/residual_0p5.npz"
TARGET_ALL="$N019_OFFICIAL_DATA/processed/embeddings/nt_ecapa_residual_all1158_20261117/residual_0p5.npz"
LS360_SOURCE="$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360_d10paths_20261117.jsonl"
LS360_UNITS_TAR="$N019_OFFICIAL_DATA/processed/ls360_units_d10_20261119.tar"
LS360_TARGET_MAP="$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_map_utterance.jsonl"
LS360_UNITS="$WORK/units/unit_records_d10.jsonl"
SUFFIX=_n019_softcap075_recovery_20261119
RUN_NAME=n019_softcap075_20261119
EXPECTED_LS360=104014
SHARDS=4

for required in \
  "$TEST_SOURCE" "$TEST_TARGET_MAP" "$VOCODER" "$DURATION_MODEL" \
  "$TARGET_TEST" "$TARGET_ALL" "$LS360_SOURCE" "$LS360_UNITS_TAR" \
  "$LS360_TARGET_MAP" "$VPC_ROOT/libri_test/wav.scp" \
  "$VPC_ROOT/libri_test_enrolls/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/trials" \
  "$VPC_ROOT/libri_test_trials_m/wav.scp" \
  "$VPC_ROOT/libri_test_trials_m/trials" \
  "$VPC_ROOT/train-clean-360/wav.scp"; do
  test -s "$required" || {
    echo "Missing soft-cap 0.75 full-S input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$TEST_SOURCE")" = 1934
test "$(wc -l < "$TEST_TARGET_MAP")" = 1934
test "$(wc -l < "$LS360_SOURCE")" = "$EXPECTED_LS360"
test "$(wc -l < "$LS360_TARGET_MAP")" = "$EXPECTED_LS360"
test "$(sha256sum "$LS360_UNITS_TAR" | awk '{print $1}')" = \
  "3c97c807cce1a6655dabbf31238c20ac1ad7dde41f9ee73180e4ab9a5c8d1404"
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = \
  "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = \
  "8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"
test "$(sha256sum "$TARGET_TEST" | awk '{print $1}')" = \
  "7a015304bebdcd12bcb4deda5792ea1941159650eff4c97367716b0748e690ef"
test "$(sha256sum "$TARGET_ALL" | awk '{print $1}')" = \
  "117fb0f1fc2fc9593e7668dbcad46abcbe22a0fa363bab803f68e8f1a612b9f2"

echo "ai_task=${MARSV2_TASK_ID:-manual} host=$(hostname) date=$(date -Is)"
echo "purpose=soft-cap0.75 matching E-VPC S and W-NT S"
echo "work=$WORK public_out=$PUBLIC_OUT"
echo "resources=1 DCU 15 CPU 59GB wall=6h expected=4h worst=6h"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

tar -C "$WORK/units" -xf "$LS360_UNITS_TAR"
python - "$WORK/units/unit_records.jsonl" "$LS360_UNITS" "$WORK/units/codes" <<'PY'
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
codes_dir = Path(sys.argv[3])
rows = 0
with source.open(encoding="utf-8") as reader, destination.open(
    "w", encoding="utf-8"
) as writer:
    for line in reader:
        row = json.loads(line)
        row["codes_path"] = str(codes_dir / Path(row["codes_path"]).name)
        writer.write(json.dumps(row, sort_keys=True) + "\n")
        rows += 1
if rows != 104014:
    raise SystemExit(f"Unexpected LS360 unit-record count: {rows}")
print(f"REWROTE_LS360_UNIT_RECORDS rows={rows}")
PY

TEST_SOURCE_SHA="$(sha256sum "$TEST_SOURCE" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"

export N019_LIBRI_TEST_SOURCE="$TEST_SOURCE"
export N019_LIBRI_TEST_UNITS="$TEST_SOURCE"
export N019_LIBRI_TEST_TARGET_MAP="$TEST_TARGET_MAP"
export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$TARGET_TEST"
export N019_LIBRI_TEST_TARGET_EMBEDDING_KEY=target_speaker
export N019_LIBRI_TEST_TARGET_EMBEDDING_MODE=speaker_mean_l2
export N019_LIBRI_TEST_DURATION_MODE=pred
export N019_LIBRI_TEST_DURATION_MODEL="$DURATION_MODEL"
export N019_LIBRI_TEST_VOCODER="$VOCODER"
export N019_LIBRI_TEST_VPC_DATA="$VPC_ROOT"
export N019_LIBRI_TEST_ANON_OUT="$TEST_OUT/anonymised"
export N019_LIBRI_TEST_SUFFIX="$SUFFIX"
export N019_LIBRI_TEST_VERIFY="$TEST_OUT/verification.json"
export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA="$TEST_SOURCE_SHA"
export N019_LIBRI_TEST_EXPECTED_DURATION_SHA="$DURATION_SHA"
export N019_LIBRI_TEST_EXPECTED_VOCODER_SHA="$VOCODER_SHA"
export N019_SPEAKER_EMBEDDING_SCALE=1.0
export N019_DURATION_EXTRAPOLATION=0.5
export N019_DURATION_PRESERVE_TOTAL=1
export N019_DURATION_SOFT_CAP_FRAMES=0.75
bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

python "$ROOT/scripts/prepare_ls360_anonymise_shards.py" \
  --source-manifest "$LS360_SOURCE" \
  --unit-records "$LS360_UNITS" \
  --target-map "$LS360_TARGET_MAP" \
  --out-dir "$SHARD_ROOT" \
  --shards "$SHARDS" \
  --expected-records "$EXPECTED_LS360"

for ((index = 0; index < SHARDS; index++)); do
  shard_dir="$SHARD_ROOT/shard_$index"
  mkdir -p "$shard_dir/anon"
  N019_SOURCE_MANIFEST="$shard_dir/manifest.jsonl" \
  N019_UNIT_RECORDS="$shard_dir/unit_records.jsonl" \
  N019_TARGET_MAP="$shard_dir/target_map.jsonl" \
  N019_ANON_OUT="$shard_dir/anon" \
  N019_SKIP_VPC_EXPORT=1 \
  N019_DATA_SUFFIX="$SUFFIX" \
  N019_DURATION_MODE=pred \
  N019_DURATION_MODEL="$DURATION_MODEL" \
  N019_VOCODER_TYPE=nt \
  N019_VOCODER="$VOCODER" \
  N019_VOCODER_EMBEDDINGS="$TARGET_ALL" \
  N019_TARGET_EMBEDDING_KEY=target_speaker \
  N019_TARGET_EMBEDDING_MODE=speaker_mean_l2 \
  N019_SPEAKER_EMBEDDING_SCALE=1.0 \
  N019_DURATION_EXTRAPOLATION=0.5 \
  N019_DURATION_PRESERVE_TOTAL=1 \
  N019_DURATION_SOFT_CAP_FRAMES=0.75 \
    bash "$ROOT/scripts/anonymize_ls360_remote.sh"
done

python "$ROOT/scripts/merge_ls360_anonymisation_shards.py" \
  --source-manifest "$LS360_SOURCE" \
  --shard-root "$SHARD_ROOT" \
  --shards "$SHARDS" \
  --out-dir "$ANON_OUT" \
  --expected-records "$EXPECTED_LS360"

python -m n019.export_vpc_anon \
  --vpc-data-dir "$VPC_ROOT" \
  --anon-manifest "$ANON_OUT/anon.jsonl" \
  --suffix "$SUFFIX" \
  --dataset-name train-clean-360 \
  --overwrite-missing

python "$ROOT/scripts/verify_anonymized_outputs.py" \
  --source-manifest "$LS360_SOURCE" \
  --out-dir "$ANON_OUT" \
  --vpc-suffix-dir "$VPC_ROOT/train-clean-360$SUFFIX" \
  --duration-mode pred \
  --vocoder-type nt \
  --expected-records "$EXPECTED_LS360" \
  --out "$ANON_OUT/verification.json"

N019_VPC_DATA="$VPC_ROOT" \
N019_DATA_SUFFIX="$SUFFIX" \
N019_RUN_NAME="$RUN_NAME" \
N019_S_EVAL_OUT="$S_EVAL_OUT" \
  bash "$ROOT/scripts/run_s_eval_remote.sh"

export N019_VPC_DATA="$VPC_ROOT"
export N019_DATA_SUFFIX="$SUFFIX"
export N019_WNT_S_RUN_NAME="$RUN_NAME"
export N019_WNT_S_OUT="$WNT_S_TRAIN_OUT"
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
  find "$WNT_S_TRAIN_OUT/snapshots" -maxdepth 1 -type d -name 'epoch*_model' \
    | sort -V | tail -n 1
)"
test -n "$WNT_S_MODEL"
test -s "$WNT_S_MODEL/model.safetensors"

export N019_WNT_S_MODEL="$WNT_S_MODEL"
export N019_WNT_ATTACKS=S
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$WNT_S_EVAL_OUT"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"

python - \
  "$S_EVAL_OUT/s_metrics.json" \
  "$WNT_S_EVAL_OUT/summary.json" \
  "$WNT_S_MODEL" \
  "$PUBLIC_OUT/summary.json" <<'PY'
import json
import sys
from pathlib import Path

s_metrics = json.loads(Path(sys.argv[1]).read_text())
wnt = json.loads(Path(sys.argv[2]).read_text())
model_dir = Path(sys.argv[3])
result = {
    "condition": "residual0.5_duration0.5_softcap0.75",
    "duration_soft_cap_frames": 0.75,
    "duration_extrapolation": 0.5,
    "preserve_predicted_total": True,
    "E_VPC_S": s_metrics,
    "W_NT_S": wnt["attacks"]["S"],
    "W_NT_S_model": str(model_dir),
    "paper": {
        "E_VPC_S": 34.8,
        "W_NT_S": 24.6,
    },
}
Path(sys.argv[4]).write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

cp "$S_EVAL_OUT/s_metrics.json" "$PUBLIC_OUT/s_metrics.json"
cp "$WNT_S_EVAL_OUT/summary.json" "$PUBLIC_OUT/wnt_s_summary.json"
cp "$ANON_OUT/verification.json" "$PUBLIC_OUT/ls360_verification.json"
mkdir -p "$PUBLIC_OUT/wnt_s_model"
cp -a "$WNT_S_MODEL/." "$PUBLIC_OUT/wnt_s_model/"
sha256sum \
  "$PUBLIC_OUT/summary.json" \
  "$PUBLIC_OUT/s_metrics.json" \
  "$PUBLIC_OUT/wnt_s_summary.json" \
  "$PUBLIC_OUT/ls360_verification.json" \
  "$PUBLIC_OUT/wnt_s_model/model.safetensors" \
  > "$PUBLIC_OUT/SHA256SUMS.txt"

chown -R 666505:666505 "$PUBLIC_OUT"
echo "N019_SOFTCAP075_FULL_S_WNTS_COMPLETE work=$WORK out=$PUBLIC_OUT"
