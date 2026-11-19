#!/bin/bash
#SBATCH --job-name=n019_du_ecapa_nt_s2
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=03:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="/public/home/a094f4d10/voice_projects/code/n019_official"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="/public/home/a094f4d10/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"
cd "$ROOT"
export TMPDIR="/dev/shm/n019_du_ecapa_nt_s2_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

SUFFIX="_n019_du_ecapa_nt_20261117"
RUN_NAME="du_ecapa_nt_20261117"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
ANON_OUT="$N019_OFFICIAL_RUNS/privacy/du_ecapa_nt_20261117_ls360/anonymised"
S_EVAL_OUT="$N019_OFFICIAL_RUNS/privacy/du_ecapa_nt_20261117_s"

test "$(wc -l < "$ANON_OUT/anon.jsonl")" = 104014
test "$(wc -l < "$VPC_ROOT/train-clean-360$SUFFIX/wav.scp")" = 104014
test "$(wc -l < "$VPC_ROOT/libri_test_enrolls$SUFFIX/wav.scp")" = 438
test "$(wc -l < "$VPC_ROOT/libri_test_trials_f$SUFFIX/trials")" = 11744
test "$(wc -l < "$VPC_ROOT/libri_test_trials_m$SUFFIX/trials")" = 9906

echo "job=${SLURM_JOB_ID:-manual} user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "purpose=S-only continuation for completed DU-ecapa-nt LS360 audio and VPC export"
echo "resources=1 DCU 16 CPU 60GB wall=3h expected=1.5 worst=3.0 card-hours"
echo "outputs=$S_EVAL_OUT"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

N019_VPC_DATA="$VPC_ROOT" \
N019_DATA_SUFFIX="$SUFFIX" \
N019_RUN_NAME="$RUN_NAME" \
N019_S_EVAL_OUT="$S_EVAL_OUT" \
  bash "$ROOT/scripts/run_s_eval_remote.sh"

sha256sum \
  "$ANON_OUT/anon.jsonl" \
  "$VPC_ROOT/train-clean-360$SUFFIX/wav.scp" \
  "$S_EVAL_OUT/s_metrics.json"

echo "N019_DU_ECAPA_NT_S_ONLY_COMPLETE out=$S_EVAL_OUT"
