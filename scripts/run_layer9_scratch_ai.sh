#!/usr/bin/env bash

set -euo pipefail

ROOT="/public/home/a094f4d10/voice_projects/code/n019_official"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="/public/home/a094f4d10/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
export TMPDIR="/dev/shm/n019_l9scratch_ai_${RANDOM}_$$"
mkdir -p "$TMPDIR"

RECORDS="$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_100_layer9_aligned/unit_records.jsonl"
EMBEDDINGS="$N019_OFFICIAL_DATA/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz"
OUT="$N019_OFFICIAL_RUNS/vocoder_nt_layer9_aligned_scratch_20261117"

for required in "$RECORDS" "$EMBEDDINGS"; do
  test -s "$required" || {
    echo "Missing layer-9 scratch input: $required" >&2
    exit 1
  }
done
test "$(wc -l < "$RECORDS")" = 33236
test ! -e "$OUT/last.pt"

export N019_VOCODER_RECORDS="$RECORDS"
export N019_VOCODER_EMBEDDINGS="$EMBEDDINGS"
export N019_VOCODER_OUT="$OUT"
export N019_VOCODER_STEPS=200000
export N019_VOCODER_MAX_HOURS=19.5
export N019_VOCODER_LR=2e-4
export N019_VOCODER_TOTAL_BATCH=16
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL=10000
export N019_VOCODER_CHECKPOINT_INTERVAL=2000
export N019_VOCODER_VALIDATION_INTERVAL=2000
export N019_VOCODER_KEEP_INTERVAL=20000
export N019_VOCODER_SELECTION_POLICY=mel_l1
export N019_VOCODER_EARLY_STOP_MIN_STEPS=200000
export N019_VOCODER_EARLY_STOP_PATIENCE=100
export N019_VOCODER_BF16=1
export N019_VOCODER_OPTIMIZER=adamw
export N019_NPROC=1

echo "job=${SLURM_JOB_ID:-ai} user=$(id -un) host=$(hostname)"
echo "purpose=paper-aligned independent layer-9 Unit HiFi-GAN training from scratch"
echo "records=$RECORDS embeddings=$EMBEDDINGS out=$OUT"

bash scripts/gpu_tiny_matmul_watchdog.sh
bash scripts/run_vocoder_ddp.sh

sha256sum "$OUT"/snapshots/generator_step*.pt "$OUT/last.pt" "$OUT/meta.json"
echo "N019_LAYER9_SCRATCH_AI_COMPLETE out=$OUT"
