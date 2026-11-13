#!/bin/bash
#SBATCH --job-name=n019_voc_main
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --gres=dcu:1
#SBATCH --mem=40G
#SBATCH --time=04:00:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

OUT="$N019_OFFICIAL_RUNS/vocoder_nt_main"
echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "job=${SLURM_JOB_ID} scope=vocoder_main out=$OUT"

bash "$N019_OFFICIAL_ROOT/scripts/preflight_dcu_remote.sh"
python -u -m n019.vocoder \
  --records "$N019_OFFICIAL_DATA/processed/units/libritts_train_clean_100/unit_records.jsonl" \
  --embeddings "$N019_OFFICIAL_DATA/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz" \
  --speaker-dim 250 \
  --embedding-level speaker \
  --out "$OUT" \
  --steps 400000 \
  --max-hours 3.8 \
  --batch-size 32 \
  --workers 4 \
  --checkpoint-interval 5000 \
  --keep-interval 50000 \
  --validation-interval 1000 \
  --device cuda \
  --bf16
