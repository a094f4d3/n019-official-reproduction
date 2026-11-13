#!/usr/bin/env bash
#SBATCH --job-name=n019_ls360_merge
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=dcu:1
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"

SOURCE="${N019_SOURCE_MANIFEST:?Set N019_SOURCE_MANIFEST}"
SHARD_ROOT="${N019_LS360_SHARD_ROOT:?Set N019_LS360_SHARD_ROOT}"
OUT="${N019_ANON_OUT:?Set N019_ANON_OUT}"
SUFFIX="${N019_DATA_SUFFIX:?Set N019_DATA_SUFFIX}"
SHARDS="${N019_LS360_SHARDS:-4}"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "source=$SOURCE"
echo "shard_root=$SHARD_ROOT"
echo "out=$OUT"
echo "suffix=$SUFFIX shards=$SHARDS"

python "$ROOT/scripts/merge_ls360_anonymisation_shards.py" \
  --source-manifest "$SOURCE" \
  --shard-root "$SHARD_ROOT" \
  --shards "$SHARDS" \
  --out-dir "$OUT" \
  --expected-records 104014

python -m n019.export_vpc_anon \
  --vpc-data-dir "$N019_OFFICIAL_DATA/vpc/data" \
  --anon-manifest "$OUT/anon.jsonl" \
  --suffix "$SUFFIX" \
  --dataset-name train-clean-360 \
  --overwrite-missing

python "$ROOT/scripts/verify_anonymized_outputs.py" \
  --source-manifest "$SOURCE" \
  --out-dir "$OUT" \
  --vpc-suffix-dir "$N019_OFFICIAL_DATA/vpc/data/train-clean-360$SUFFIX" \
  --duration-mode pred \
  --vocoder-type nt \
  --expected-records 104014 \
  --out "$OUT/verification.json"

echo "LS360_MERGE_EXPORT_COMPLETE out=$OUT"
