#!/bin/bash
#SBATCH --job-name=n019_layer9_exportwnt
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

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

OUT="$HOME/voice_projects/runs/n019_official/layer9_step8k_test_20261117"
ANON="$OUT/anonymised/anon.jsonl"
SUFFIX=_n019_layer9_8k_20261117
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"

test "$(wc -l < "$ANON")" = 1934

python -m n019.export_vpc_anon \
  --vpc-data-dir "$VPC_ROOT" \
  --anon-manifest "$ANON" \
  --suffix "$SUFFIX" \
  --dataset-name libri_test \
  --dataset-name libri_test_enrolls \
  --dataset-name libri_test_trials_f \
  --dataset-name libri_test_trials_m \
  --overwrite-missing

test "$(wc -l < "$VPC_ROOT/libri_test$SUFFIX/wav.scp")" = 1934
test "$(wc -l < "$VPC_ROOT/libri_test_enrolls$SUFFIX/wav.scp")" = 438
test "$(wc -l < "$VPC_ROOT/libri_test_trials_f$SUFFIX/wav.scp")" = 734
test "$(wc -l < "$VPC_ROOT/libri_test_trials_f$SUFFIX/trials")" = 11744
test "$(wc -l < "$VPC_ROOT/libri_test_trials_m$SUFFIX/wav.scp")" = 762
test "$(wc -l < "$VPC_ROOT/libri_test_trials_m$SUFFIX/trials")" = 9906

export N019_DATA_SUFFIX="$SUFFIX"
export N019_VPC_DATA="$VPC_ROOT"
export N019_WNT_BASE_VPC_DATA="$VPC_ROOT"
export N019_WNT_ATTACKS=L
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$OUT/wnt_l"
bash scripts/evaluate_wnt_remote.sh

sha256sum "$OUT/wnt_l/summary.json"
echo "N019_LAYER9_8K_WNT_COMPLETE out=$OUT suffix=$SUFFIX"
