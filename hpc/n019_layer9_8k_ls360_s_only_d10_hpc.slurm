#!/bin/bash
#SBATCH --job-name=n019_l9_8k_sonly
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=03:00:00
#SBATCH --exclude=f11r1n01,f11r2n13
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
export TMPDIR="/dev/shm/n019_layer9_sonly_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

RUN_ROOT="$N019_OFFICIAL_RUNS/privacy/layer9_8k_s_20261117"
SOURCE="$HOME/voice_projects/data/n019_official/processed/manifests/librispeech_train_clean_360_d10paths_20261117.jsonl"
SUFFIX="_n019_layer9_8k_20261117"
S_EVAL_OUT="$RUN_ROOT/s_eval"
VPC="$N019_OFFICIAL_DATA/vpc/data"

for required in \
  "$VPC/train-clean-360$SUFFIX/wav.scp" \
  "$VPC/libri_test_enrolls$SUFFIX/wav.scp" \
  "$VPC/libri_test_trials_f$SUFFIX/wav.scp" \
  "$VPC/libri_test_trials_m$SUFFIX/wav.scp"; do
  test -s "$required" || {
    echo "Missing aligned layer-9 VPC input: $required" >&2
    exit 1
  }
done

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "purpose=run official E-VPC S on already exported layer-9 8k VPC views"
echo "suffix=$SUFFIX output=$S_EVAL_OUT"

python "$ROOT/scripts/verify_anonymized_outputs.py" \
  --source-manifest "$SOURCE" \
  --out-dir "$RUN_ROOT/anonymised" \
  --vpc-suffix-dir "$VPC/train-clean-360$SUFFIX" \
  --duration-mode pred \
  --vocoder-type nt \
  --expected-records 104014 \
  --out "$RUN_ROOT/anonymised/verification_aligned_suffix.json"

N019_DATA_SUFFIX="$SUFFIX" \
N019_RUN_NAME="layer9_8k_s_20261117" \
N019_S_EVAL_OUT="$S_EVAL_OUT" \
  bash "$ROOT/scripts/run_s_eval_remote.sh"

sha256sum \
  "$RUN_ROOT/anonymised/verification_aligned_suffix.json" \
  "$VPC/train-clean-360$SUFFIX/wav.scp" \
  "$S_EVAL_OUT/s_metrics.json"
echo "N019_LAYER9_8K_S_ONLY_COMPLETE out=$S_EVAL_OUT"
