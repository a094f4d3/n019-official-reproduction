#!/bin/bash
#SBATCH --job-name=n019_l9cont
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=06:00:00
#SBATCH --exclude=f11r1n01,f11r2n13
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
export TMPDIR="/dev/shm/n019_layer9_cont_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

RECORDS="$HOME/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100_layer9_aligned/unit_records.jsonl"
EMBEDDINGS="/public/home/a094f4d6/voice_projects/data/n019_official/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz"
OUT="$N019_OFFICIAL_RUNS/vocoder_nt_layer9_aligned_pilot_20261116"
RESUME_SHA256="9340c3f98293564bfd61ea1039c8aab4ac678e90d32fbede0803510bed381329"

for required in "$RECORDS" "$EMBEDDINGS" "$OUT/last.pt"; do
  test -s "$required" || {
    echo "Missing layer-9 continuation input: $required" >&2
    exit 1
  }
done
test "$(sha256sum "$OUT/last.pt" | awk '{print $1}')" = "$RESUME_SHA256"

export N019_VOICE_ROOT="$HOME/voice_projects"
export N019_SHARED_VOICE_ROOT=/public/home/a094f4d6/voice_projects
export N019_VOCODER_RECORDS="$RECORDS"
export N019_VOCODER_EMBEDDINGS="$EMBEDDINGS"
export N019_VOCODER_OUT="$OUT"
export N019_VOCODER_RESUME_SHA256="$RESUME_SHA256"
export N019_VOCODER_STEPS=60000
export N019_VOCODER_MAX_HOURS=5.75
export N019_VOCODER_LR=1e-4
export N019_VOCODER_TOTAL_BATCH=16
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL=2000
export N019_VOCODER_CHECKPOINT_INTERVAL=2000
export N019_VOCODER_VALIDATION_INTERVAL=2000
export N019_VOCODER_KEEP_INTERVAL=20000
export N019_VOCODER_SELECTION_POLICY=mel_l1
export N019_VOCODER_EARLY_STOP_MIN_STEPS=60000
export N019_VOCODER_EARLY_STOP_PATIENCE=100
export N019_VOCODER_BF16=1
export N019_VOCODER_OPTIMIZER=adamw
export N019_NPROC=1

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "purpose=continue layer-9 aligned vocoder from step 10120 to 60000"
echo "records=$RECORDS embeddings=$EMBEDDINGS out=$OUT"
echo "resume_sha256=$RESUME_SHA256"

bash scripts/gpu_tiny_matmul_watchdog.sh
bash scripts/run_vocoder_ddp.sh

sha256sum "$OUT"/snapshots/generator_step*.pt "$OUT/last.pt"
echo "N019_LAYER9_CONTINUE_COMPLETE out=$OUT"
