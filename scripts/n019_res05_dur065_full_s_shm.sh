#!/usr/bin/env bash

set -euo pipefail

PUBLIC_ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
export N019_VOICE_ROOT=/public/home/a094f4d10/voice_projects
source "$PUBLIC_ROOT/hpc/activate_n019_official.sh"

WORK="/dev/shm/n019_res05_dur065_s_${SLURM_JOB_ID:-manual}"
VPC_ROOT="$WORK/vpc"
TEST_OUT="$WORK/test"
SHARD_ROOT="$WORK/ls360_shards"
ANON_OUT="$WORK/ls360_anon"
S_EVAL_OUT="$WORK/s_eval"
mkdir -p "$WORK/tmp" "$VPC_ROOT" "$TEST_OUT" "$SHARD_ROOT" \
  "$ANON_OUT" "$S_EVAL_OUT" "$WORK/logs" "$WORK/runs" "$WORK/miopen"
cp -a "$PUBLIC_ROOT" "$WORK/code"
python - "$WORK/code/vendor/Voice-Privacy-Challenge-2024/evaluation/privacy/asv/asv_train/train_speaker_embeddings.py" <<'PY'
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
ROOT="$WORK/code"
export N019_OFFICIAL_ROOT="$ROOT"
cd "$ROOT"
export TMPDIR="$WORK/tmp"
export N019_OFFICIAL_LOGS="$WORK/logs"
export N019_OFFICIAL_RUNS="$WORK/runs"
export MIOPEN_USER_DB_PATH="$WORK/miopen"
export MIOPEN_CUSTOM_CACHE_DIR="$WORK/miopen"

TEST_SOURCE=/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/libri_test.jsonl
TEST_UNITS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libri_test_paperfix/unit_records.jsonl
TEST_TARGET_MAP=/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl
LS360_SOURCE="$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360_d10paths_20261117.jsonl"
LS360_UNITS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/librispeech_train_clean_360/unit_records.jsonl
LS360_TARGET_MAP="$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_map_utterance.jsonl"
TARGET_050_TEST="$N019_OFFICIAL_DATA/processed/embeddings/nt_ecapa_residual_test_20261117/residual_0p5.npz"
TARGET_050_ALL="$N019_OFFICIAL_DATA/processed/embeddings/nt_ecapa_residual_all1158_20261117/residual_0p5.npz"
DURATION_MODEL=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt
VOCODER="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt"
VPC_SOURCE="$N019_OFFICIAL_DATA/vpc/data"
SUFFIX="_n019_n019_res05_dur065_20261118"
RUN_NAME="n019_res05_dur065_20261118"
EXPECTED_LS360=104014
SHARDS=4

for required in \
  "$TEST_SOURCE" "$TEST_UNITS" "$TEST_TARGET_MAP" \
  "$LS360_SOURCE" "$LS360_UNITS" "$LS360_TARGET_MAP" \
  "$TARGET_050_TEST" "$TARGET_050_ALL" "$DURATION_MODEL" "$VOCODER" \
  "$VPC_SOURCE/libri_test/wav.scp" \
  "$VPC_SOURCE/libri_test_enrolls/wav.scp" \
  "$VPC_SOURCE/libri_test_trials_f/wav.scp" \
  "$VPC_SOURCE/libri_test_trials_f/trials" \
  "$VPC_SOURCE/libri_test_trials_m/wav.scp" \
  "$VPC_SOURCE/libri_test_trials_m/trials" \
  "$VPC_SOURCE/train-clean-360/wav.scp"; do
  test -s "$required" || {
    echo "Missing duration0.65 S input: $required" >&2
    exit 1
  }
done

for dataset in \
  libri_test \
  libri_test_enrolls \
  libri_test_trials_f \
  libri_test_trials_m \
  train-clean-360; do
  mkdir -p "$VPC_ROOT/$dataset"
  for source_entry in "$VPC_SOURCE/$dataset"/*; do
    ln -sfn "$source_entry" "$VPC_ROOT/$dataset/$(basename "$source_entry")"
  done
done
mkdir -p "$VPC_ROOT/data/libri_test"
ln -sfn "$VPC_SOURCE/libri_test/wav" "$VPC_ROOT/data/libri_test/wav"

test "$(wc -l < "$TEST_SOURCE")" = 1934
test "$(wc -l < "$TEST_UNITS")" = 1934
test "$(wc -l < "$TEST_TARGET_MAP")" = 1934
test "$(wc -l < "$LS360_SOURCE")" = "$EXPECTED_LS360"
test "$(wc -l < "$LS360_UNITS")" = "$EXPECTED_LS360"
test "$(wc -l < "$LS360_TARGET_MAP")" = "$EXPECTED_LS360"
test "$(sha256sum "$TARGET_050_TEST" | awk '{print $1}')" = \
  "7a015304bebdcd12bcb4deda5792ea1941159650eff4c97367716b0748e690ef"
test "$(sha256sum "$TARGET_050_ALL" | awk '{print $1}')" = \
  "117fb0f1fc2fc9593e7668dbcad46abcbe22a0fa363bab803f68e8f1a612b9f2"
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = \
  "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = \
  "8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=full matching E-VPC S for residual0.5 duration0.65"
echo "suffix=$SUFFIX expected_ls360=$EXPECTED_LS360 shards=$SHARDS"
echo "work=$WORK"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

TEST_SOURCE_SHA="$(sha256sum "$TEST_SOURCE" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"
VOCODER_SHA="$(sha256sum "$VOCODER" | awk '{print $1}')"

export N019_LIBRI_TEST_SOURCE="$TEST_SOURCE"
export N019_LIBRI_TEST_UNITS="$TEST_UNITS"
export N019_LIBRI_TEST_TARGET_MAP="$TEST_TARGET_MAP"
export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$TARGET_050_TEST"
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
export N019_DURATION_EXTRAPOLATION=0.65
export N019_DURATION_PRESERVE_TOTAL=1
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
  N019_VOCODER_EMBEDDINGS="$TARGET_050_ALL" \
  N019_TARGET_EMBEDDING_KEY=target_speaker \
  N019_TARGET_EMBEDDING_MODE=speaker_mean_l2 \
  N019_SPEAKER_EMBEDDING_SCALE=1.0 \
  N019_DURATION_EXTRAPOLATION=0.65 \
  N019_DURATION_PRESERVE_TOTAL=1 \
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

python - "$S_EVAL_OUT/s_metrics.json" "$WORK/summary.json" <<'PY'
import json
import sys
from pathlib import Path

metrics = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
destination = Path(sys.argv[2])
result = {
    "system": "DU-pred-nt residual0.5 duration0.65",
    "paper_E_VPC_S": 34.8,
    "formal_E_VPC_S": 29.7425,
    "residual0.5_duration0.5_E_VPC_S": 33.255,
    "s_metrics": metrics,
}
destination.write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$TEST_OUT/anonymised/anon.jsonl" \
  "$TEST_OUT/verification.json" \
  "$ANON_OUT/anon.jsonl" \
  "$ANON_OUT/verification.json" \
  "$VPC_ROOT/train-clean-360$SUFFIX/wav.scp" \
  "$S_EVAL_OUT/s_metrics.json" \
  "$WORK/summary.json"
echo "N019_RES05_DUR065_S_COMPLETE work=$WORK"
echo "Holding /dev/shm for recovery"
sleep 7200
