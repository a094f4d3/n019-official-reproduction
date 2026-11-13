#!/usr/bin/env bash
#SBATCH --job-name=n019_ls360_sharded
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --gres=dcu:4
#SBATCH --mem=120G
#SBATCH --time=06:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

export N019_LS360_SHARDS="${N019_LS360_SHARDS:-4}"
export N019_LS360_EXPECTED_RECORDS="${N019_LS360_EXPECTED_RECORDS:-104014}"
export N019_ANON_OUT="${N019_ANON_OUT:?Set N019_ANON_OUT}"
export N019_DATA_SUFFIX="${N019_DATA_SUFFIX:?Set N019_DATA_SUFFIX}"
export N019_VOCODER="${N019_VOCODER:?Set N019_VOCODER}"
export N019_VOCODER_EMBEDDINGS="${N019_VOCODER_EMBEDDINGS:?Set N019_VOCODER_EMBEDDINGS}"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "shards=$N019_LS360_SHARDS"
echo "expected_records=$N019_LS360_EXPECTED_RECORDS"
echo "suffix=$N019_DATA_SUFFIX"
echo "vocoder=$N019_VOCODER"
echo "embedding=$N019_VOCODER_EMBEDDINGS"
echo "out=$N019_ANON_OUT"

bash "$ROOT/scripts/run_ls360_anonymise_sharded_remote.sh"
