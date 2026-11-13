#!/bin/bash
#SBATCH --job-name=n019_lr5e5_2k_d7
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

export N019_OFFICIAL_ROOT="$HOME/voice_projects/code/n019_official_diag_20261110"
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

INIT="$HOME/voice_projects/tmp/n019_d5_snapshots_20261110/generator_step00092000.pt"
INIT_SHA="f203505cdfc90df0a77b37c3c08870dd7421f076aad226ba3429937aa8ee72f7"
OUT="$N019_OFFICIAL_RUNS/vocoder_nt_hpc_lr5e5_2k_from92k_20261110"

if [[ ! -f "$INIT" ]]; then
  echo "Missing init generator: $INIT" >&2
  exit 1
fi
actual="$(sha256sum "$INIT" | awk '{print $1}')"
if [[ "$actual" != "$INIT_SHA" ]]; then
  echo "Init generator SHA256 mismatch: $actual" >&2
  exit 1
fi

mkdir -p "$OUT"
echo "user=$(id -un) host=$(hostname) date=$(date -Is) job=${SLURM_JOB_ID}"
echo "mode=short_anneal from=92k steps=2000 lr=5e-5 batch=16 precision=bf16"
echo "init=$INIT sha256=$INIT_SHA"
echo "output=$OUT"

export N019_NPROC=1
export N019_VOCODER_TOTAL_BATCH=16
export N019_VOCODER_WORKERS=4
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RUN_NAME="$(basename "$OUT")"
export N019_VOCODER_OUT="$OUT"
export N019_VOCODER_STEPS=2000
export N019_VOCODER_MAX_HOURS=0.90
export N019_VOCODER_CHECKPOINT_INTERVAL=2000
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL=500
export N019_VOCODER_KEEP_INTERVAL=10000
export N019_VOCODER_VALIDATION_INTERVAL=1000
export N019_VOCODER_VALIDATION_LIMIT=32
export N019_VOCODER_SELECTION_POLICY=mos_offline
export N019_VOCODER_EARLY_STOP_MIN_STEPS=2000
export N019_VOCODER_EARLY_STOP_PATIENCE=0
export N019_VOCODER_LR=5e-5
export N019_VOCODER_GRAD_CLIP_NORM=0.0
export N019_VOCODER_BF16=1
export N019_VOCODER_INIT_GENERATOR="$INIT"
export N019_VOCODER_INIT_GENERATOR_SHA256="$INIT_SHA"
export N019_SKIP_PATH_VERIFY=1
export N019_TRAINING_DATA_MARKER="$N019_OFFICIAL_LOGS/d7_training_data_marker_20261110.json"
export N019_TRAINING_EXPECTED_ROWS=33236
export N019_STAGE_TRACE=1

bash "$N019_OFFICIAL_ROOT/scripts/run_vocoder_ddp.sh"
