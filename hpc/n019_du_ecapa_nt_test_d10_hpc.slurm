#!/bin/bash
#SBATCH --job-name=n019_du_ecapa_nt
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=04:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="/public/home/a094f4d10/voice_projects/code/n019_official"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="/public/home/a094f4d10/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"
cd "$ROOT"

export TMPDIR="/dev/shm/n019_du_ecapa_nt_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

LABEL="du_ecapa_nt_20261117"
SUFFIX="_n019_${LABEL}"

LS100_MANIFEST="/public/home/a094f4d4/voice_projects/data/n019_official/processed/manifests/librispeech_train_clean_100.jsonl"
LS100_RECORDS="/public/home/a094f4d4/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100/unit_records.jsonl"
OTHER500_MANIFEST="/public/home/a094f4d4/voice_projects/data/n019_official/processed/manifests/libritts_train_other_500.jsonl"

TEST_BUNDLE="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117"
TEST_RECORDS="$TEST_BUNDLE/units/unit_records.jsonl"
TEST_TARGET_MAP="$TEST_BUNDLE/target_map.jsonl"
TEST_VOCODER="$TEST_BUNDLE/assets/generator_soup2.pt"
TEST_VOCODER_SHA="ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"

NT_TARGET_EMBEDDINGS="/public/home/a094f4d6/voice_projects/tmp/n019_privacy_fix_20261111/target_speaker_mean32_all1158_shrink01.npz"
ECAPA_MODEL="$N019_OFFICIAL_MODELS/vpc/exp/asv_orig"
TARGET_SAMPLE_MANIFEST="$N019_OFFICIAL_DATA/processed/targets/target_speaker_mean32_all1158_20261117.jsonl"
TARGET_SAMPLE_SUMMARY="$N019_OFFICIAL_DATA/processed/targets/target_speaker_mean32_all1158_20261117.summary.json"

SOURCE_ECAPA_DIR="$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_100_ecapa_20261117"
SOURCE_ECAPA="$SOURCE_ECAPA_DIR/ecapa_speaker_embeddings.npz"
TARGET_ECAPA_DIR="$N019_OFFICIAL_DATA/processed/embeddings/target_speaker_mean32_ecapa_all1158_20261117"
TARGET_ECAPA="$TARGET_ECAPA_DIR/ecapa_speaker_embeddings.npz"
DURATION_OUT="$N019_OFFICIAL_RUNS/duration_ecapa_main_20261117"
DURATION_MODEL="$DURATION_OUT/best.pt"

ANON_OUT="$N019_OFFICIAL_DATA/anonymised/libri_test/DU-ecapa-nt-20261117"
EVAL_OUT="$N019_OFFICIAL_RUNS/eval/${LABEL}"
WNT_OUT="$N019_OFFICIAL_RUNS/eval/${LABEL}_wnt"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc_ai/data"

for required in \
  "$LS100_MANIFEST" \
  "$LS100_RECORDS" \
  "$OTHER500_MANIFEST" \
  "$TEST_RECORDS" \
  "$TEST_TARGET_MAP" \
  "$TEST_VOCODER" \
  "$NT_TARGET_EMBEDDINGS" \
  "$TARGET_SAMPLE_MANIFEST" \
  "$TARGET_SAMPLE_SUMMARY" \
  "$ECAPA_MODEL/hyperparams.yaml" \
  "$ECAPA_MODEL/embedding_model.ckpt" \
  "$ECAPA_MODEL/classifier.ckpt"; do
  test -s "$required" || {
    echo "Missing DU-ecapa-nt input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$LS100_MANIFEST")" = 28539
test "$(wc -l < "$LS100_RECORDS")" = 28539
test "$(wc -l < "$TEST_RECORDS")" = 1934
test "$(wc -l < "$TEST_TARGET_MAP")" = 1934
test "$(wc -l < "$TARGET_SAMPLE_MANIFEST")" = 36560
test "$(sha256sum "$TEST_VOCODER" | awk '{print $1}')" = "$TEST_VOCODER_SHA"

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=paper-aligned DU-ecapa-nt full test screen"
echo "duration=LibriSpeech-clean-100 ECAPA speaker conditional"
echo "vocoder=formal NT soup conditioned on target NT mean32 shrink0.1"
echo "target_ecapa=1158 speakers x 32 utterances"
echo "resources=1 DCU 16 CPU 60GB wall=4h"
echo "outputs=$ANON_OUT $EVAL_OUT $WNT_OUT"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"
bash "$ROOT/scripts/preflight_du_ecapa_nt_inputs_d10.sh"

if [[ ! -s "$SOURCE_ECAPA" ]]; then
  python -u -m n019.extract_speakers \
    --manifest "$LS100_MANIFEST" \
    --model "$ECAPA_MODEL" \
    --kind ecapa \
    --level speaker \
    --checkpoint-every 100 \
    --resume \
    --device cuda \
    --out "$SOURCE_ECAPA_DIR" 2>&1 | tee "$SOURCE_ECAPA_DIR.log"
fi

python - "$SOURCE_ECAPA" 251 <<'PY'
import sys
from pathlib import Path

import numpy as np

path = Path(sys.argv[1])
expected = int(sys.argv[2])
archive = np.load(path, allow_pickle=False)
try:
    keys = list(archive.files)
    if len(keys) != expected:
        raise SystemExit(f"Expected {expected} source ECAPA speakers, got {len(keys)}")
    if any(archive[key].shape != (192,) for key in keys):
        raise SystemExit("Source ECAPA dimensions are not 192")
    if any(not np.isfinite(archive[key]).all() for key in keys):
        raise SystemExit("Source ECAPA embeddings contain non-finite values")
finally:
    archive.close()
print(f"SOURCE_ECAPA_OK speakers={expected} dim=192")
PY

mkdir -p "$DURATION_OUT"
DURATION_RESUME=()
if [[ -s "$DURATION_OUT/last.pt" ]]; then
  DURATION_RESUME=(--resume)
fi
python -u -m n019.duration \
  --records "$LS100_RECORDS" \
  --embeddings "$SOURCE_ECAPA" \
  --speaker-dim 192 \
  --embedding-kind ecapa \
  --epochs 30 \
  --batch-size 32 \
  --workers 4 \
  --device cuda \
  --out "$DURATION_OUT" \
  "${DURATION_RESUME[@]}" 2>&1 | tee "$DURATION_OUT.log"

test -s "$DURATION_MODEL"

if [[ ! -s "$TARGET_ECAPA" ]]; then
  python -u -m n019.extract_speakers \
    --manifest "$TARGET_SAMPLE_MANIFEST" \
    --model "$ECAPA_MODEL" \
    --kind ecapa \
    --level speaker \
    --checkpoint-every 128 \
    --resume \
    --device cuda \
    --out "$TARGET_ECAPA_DIR" 2>&1 | tee "$TARGET_ECAPA_DIR.log"
fi

python - "$TARGET_ECAPA" "$TEST_TARGET_MAP" \
  "$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_map_utterance.jsonl" <<'PY'
import json
import sys
from pathlib import Path

import numpy as np

embedding_path = Path(sys.argv[1])
target_maps = [Path(value) for value in sys.argv[2:]]
required = set()
for path in target_maps:
    for line in path.open(encoding="utf-8"):
        if line.strip():
            required.add(str(json.loads(line)["target_speaker"]))

archive = np.load(embedding_path, allow_pickle=False)
try:
    keys = set(archive.files)
    missing = sorted(required - keys)
    if missing:
        raise SystemExit(f"Missing target ECAPA speakers: {missing[:10]}")
    if len(keys) != 1158:
        raise SystemExit(f"Expected 1158 target ECAPA speakers, got {len(keys)}")
    if any(archive[key].shape != (192,) for key in keys):
        raise SystemExit("Target ECAPA dimensions are not 192")
    if any(not np.isfinite(archive[key]).all() for key in keys):
        raise SystemExit("Target ECAPA embeddings contain non-finite values")
finally:
    archive.close()
print(f"TARGET_ECAPA_OK speakers=1158 required={len(required)} dim=192")
PY

SOURCE_SHA="$(sha256sum "$TEST_RECORDS" | awk '{print $1}')"
DURATION_SHA="$(sha256sum "$DURATION_MODEL" | awk '{print $1}')"

export N019_LIBRI_TEST_SOURCE="$TEST_RECORDS"
export N019_LIBRI_TEST_UNITS="$TEST_RECORDS"
export N019_LIBRI_TEST_TARGET_MAP="$TEST_TARGET_MAP"
export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA="$SOURCE_SHA"
export N019_LIBRI_TEST_EXPECTED_DURATION_SHA="$DURATION_SHA"

export N019_EVAL_LABEL="$LABEL"
export N019_EVAL_SYSTEM="DU-ecapa-nt"
export N019_EVAL_VPC_DATA="$VPC_ROOT"
export N019_EVAL_VOCODER="$TEST_VOCODER"
export N019_EVAL_VOC_SHA="$TEST_VOCODER_SHA"
export N019_EVAL_STEPS="96000"
export N019_EVAL_TARGET_EMBEDDINGS="$NT_TARGET_EMBEDDINGS"
export N019_EVAL_TARGET_EMBEDDING_KEY="target_speaker"
export N019_EVAL_TARGET_EMBEDDING_MODE="speaker_mean_l2"
export N019_EVAL_DURATION_MODE="ecapa"
export N019_EVAL_DURATION_MODEL="$DURATION_MODEL"
export N019_EVAL_DURATION_EMBEDDINGS="$TARGET_ECAPA"
export N019_EVAL_DURATION_EMBEDDING_KEY="target_speaker"
export N019_EVAL_ANON_OUT="$ANON_OUT"
export N019_EVAL_OUT="$EVAL_OUT"
unset N019_LIBRI_TEST_EXPECTED_VOCODER_SHA

bash "$ROOT/scripts/run_full_eval_param_ai.sh"

export N019_VPC_DATA="$VPC_ROOT"
export N019_DATA_SUFFIX="$SUFFIX"
export N019_RUN_NAME="${LABEL}_wnt"
export N019_WNT_ATTACKS="I L"
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$WNT_OUT"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"

python - "$EVAL_OUT" "$WNT_OUT" "$TARGET_ECAPA" "$DURATION_MODEL" <<'PY'
import json
import sys
from pathlib import Path

eval_out, wnt_out = map(Path, sys.argv[1:3])
quality = json.loads((eval_out / "quality_metrics.json").read_text(encoding="utf-8"))
wnt = json.loads((wnt_out / "summary.json").read_text(encoding="utf-8"))
result = {
    "system": "DU-ecapa-nt",
    "quality": quality["values"],
    "paper_quality": {"WER": 7.41, "UTMOS": 3.63, "WhiSQA": 3.69},
    "wnt_I": float(wnt["attacks"]["I"]),
    "wnt_L": float(wnt["attacks"]["L"]),
    "paper_wnt_I": 39.9,
    "paper_wnt_L": 42.3,
    "target_ecapa": sys.argv[3],
    "duration_model": sys.argv[4],
}
(eval_out / "du_ecapa_nt_summary.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$SOURCE_ECAPA" \
  "$TARGET_ECAPA" \
  "$DURATION_MODEL" \
  "$TEST_VOCODER" \
  "$ANON_OUT/anon.jsonl" \
  "$EVAL_OUT/WER.json" \
  "$EVAL_OUT/mos/UTMOS.json" \
  "$EVAL_OUT/mos/WhiSQA.json" \
  "$EVAL_OUT/quality_metrics.json" \
  "$EVAL_OUT/du_ecapa_nt_summary.json" \
  "$WNT_OUT/summary.json"

echo "N019_DU_ECAPA_NT_TEST_COMPLETE out=$EVAL_OUT"
