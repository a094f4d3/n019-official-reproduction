#!/usr/bin/env bash
#SBATCH --job-name=n019_ls360_shard
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=06:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"

: "${N019_SOURCE_MANIFEST:?Set N019_SOURCE_MANIFEST}"
: "${N019_UNIT_RECORDS:?Set N019_UNIT_RECORDS}"
: "${N019_TARGET_MAP:?Set N019_TARGET_MAP}"
: "${N019_ANON_OUT:?Set N019_ANON_OUT}"
: "${N019_DATA_SUFFIX:?Set N019_DATA_SUFFIX}"
: "${N019_VOCODER:?Set N019_VOCODER}"
: "${N019_VOCODER_EMBEDDINGS:?Set N019_VOCODER_EMBEDDINGS}"

export N019_SOURCE_MANIFEST
export N019_UNIT_RECORDS
export N019_TARGET_MAP
export N019_ANON_OUT
export N019_DATA_SUFFIX
export N019_VOCODER
export N019_VOCODER_EMBEDDINGS
export N019_SKIP_VPC_EXPORT=1
export N019_DURATION_MODE=pred
export N019_VOCODER_TYPE=nt
export N019_TARGET_EMBEDDING_KEY="${N019_TARGET_EMBEDDING_KEY:-target_speaker}"
export N019_TARGET_EMBEDDING_MODE="${N019_TARGET_EMBEDDING_MODE:-speaker_mean_l2_shrink0.1}"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "source=$N019_SOURCE_MANIFEST"
echo "units=$N019_UNIT_RECORDS"
echo "targets=$N019_TARGET_MAP"
echo "out=$N019_ANON_OUT"
echo "target_embedding_key=$N019_TARGET_EMBEDDING_KEY"
echo "target_embedding_mode=$N019_TARGET_EMBEDDING_MODE"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

bash "$ROOT/scripts/anonymize_ls360_remote.sh"
