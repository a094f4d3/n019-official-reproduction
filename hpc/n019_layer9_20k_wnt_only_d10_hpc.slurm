#!/bin/bash
#SBATCH --job-name=n019_layer9_20k_wnt
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=01:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="/public/home/a094f4d10/voice_projects/code/n019_official"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="/public/home/a094f4d10/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"
cd "$ROOT"
export TMPDIR="/dev/shm/n019_layer9_20k_wnt_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
SOURCE_WAV_ROOT="$N019_OFFICIAL_DATA/vpc_ai/data/data/libri_test/wav"
OUT="$N019_OFFICIAL_RUNS/layer9_step20k_test_20261117/wnt_il"
SUFFIX="_n019_layer9_20k_20261117"

test "$(find "$SOURCE_WAV_ROOT" -maxdepth 1 -type f -name '*.wav' | wc -l)" = 1934
test "$(wc -l < "$VPC_ROOT/libri_test$SUFFIX/wav.scp")" = 1934
test "$(wc -l < "$VPC_ROOT/libri_test_enrolls$SUFFIX/wav.scp")" = 438
test "$(wc -l < "$VPC_ROOT/libri_test_trials_f$SUFFIX/trials")" = 11744
test "$(wc -l < "$VPC_ROOT/libri_test_trials_m$SUFFIX/trials")" = 9906

# The metadata-only VPC wav.scp files use paths like
# data/libri_test/wav/<id>.wav. eval_wnt resolves those against the VPC root.
if [[ ! -e "$VPC_ROOT/data/libri_test/wav" ]]; then
  mkdir -p "$VPC_ROOT/data/libri_test"
  ln -s "$SOURCE_WAV_ROOT" "$VPC_ROOT/data/libri_test/wav"
fi
test -f "$VPC_ROOT/data/libri_test/wav/121-121726-0000.wav"

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=W-NT-only completion for the already evaluated layer-9 20k checkpoint"
echo "reuses complete anonymised audio and VPC views; does not rerun WER/UTMOS/WhiSQA"
echo "resources=1 DCU 16 CPU 60GB wall=1h expected=0.1 worst=1.0 card-hours"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

export N019_DATA_SUFFIX="$SUFFIX"
export N019_VPC_DATA="$VPC_ROOT"
export N019_WNT_BASE_VPC_DATA="$VPC_ROOT"
export N019_WNT_ATTACKS="I L"
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$OUT"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"

sha256sum "$OUT/summary.json"
echo "N019_LAYER9_20K_WNT_COMPLETE out=$OUT"
