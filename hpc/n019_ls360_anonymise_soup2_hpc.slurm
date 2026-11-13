#!/usr/bin/env bash
#SBATCH --job-name=n019_ls360_soup2
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

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

export N019_DURATION_MODE=pred
export N019_VOCODER_TYPE=nt
export N019_DATA_SUFFIX="${N019_DATA_SUFFIX:-_n019_soup2_w40_shrink01_20261110}"
export N019_VOCODER="${N019_VOCODER:?Set N019_VOCODER}"
export N019_VOCODER_EMBEDDINGS="${N019_VOCODER_EMBEDDINGS:?Set N019_VOCODER_EMBEDDINGS}"
export N019_TARGET_EMBEDDING_KEY=target_speaker
export N019_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1
export N019_ANON_OUT="${N019_ANON_OUT:-$N019_OFFICIAL_DATA/anonymised/ls360/DU-pred-nt-soup2_w40_shrink01_20261110}"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "suffix=$N019_DATA_SUFFIX"
echo "vocoder=$N019_VOCODER"
echo "embedding=$N019_VOCODER_EMBEDDINGS"
echo "out=$N019_ANON_OUT"

bash "$ROOT/scripts/anonymize_ls360_remote.sh"
python "$ROOT/scripts/verify_anonymized_outputs.py" \
  --source-manifest "$N019_OFFICIAL_DATA/processed/manifests/librispeech_train_clean_360.jsonl" \
  --out-dir "$N019_ANON_OUT" \
  --vpc-suffix-dir "$N019_OFFICIAL_DATA/vpc/data/train-clean-360$N019_DATA_SUFFIX" \
  --duration-mode pred \
  --vocoder-type nt \
  --expected-records 104014 \
  --out "$N019_ANON_OUT/verification.json"
