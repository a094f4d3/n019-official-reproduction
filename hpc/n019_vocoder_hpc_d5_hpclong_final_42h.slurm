#!/bin/bash
#SBATCH --job-name=n019_vocd5_final_42h
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=42:45:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

export N019_OFFICIAL_ROOT="$HOME/voice_projects/code/n019_official_lr2e4_hpc_20261109"
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

readonly D6_SOURCE_RUN="/public/home/a094f4d6/voice_projects/runs/n019_official/vocoder_nt_hpc_ft14k_long_20261109"
readonly D6_SOURCE_CHECKPOINT="$D6_SOURCE_RUN/last.pt"
readonly RUN_NAME="vocoder_nt_hpc_d5_hpclongfinal_20261110"
export N019_VOCODER_OUT="$N019_OFFICIAL_RUNS/$RUN_NAME"
readonly TARGET_CHECKPOINT="$N019_VOCODER_OUT/last.pt"

echo "user=$(id -un) host=$(hostname) date=$(date -Is) job=${SLURM_JOB_ID}"
echo "mode=HPC resume dcu=1 total_batch=16 budget=42.25h precision=bf16"
echo "source_checkpoint=$D6_SOURCE_CHECKPOINT"
echo "target_checkpoint=$TARGET_CHECKPOINT"

if [[ ! -r "$D6_SOURCE_CHECKPOINT" ]]; then
  echo "Missing or unreadable hpclong final checkpoint: $D6_SOURCE_CHECKPOINT" >&2
  exit 1
fi

source_step="$(
  python - "$D6_SOURCE_CHECKPOINT" <<'PY'
import sys
import torch

checkpoint = torch.load(sys.argv[1], map_location="cpu", weights_only=False)
required = {
    "step",
    "generator",
    "mpd",
    "msd",
    "optimizer_g",
    "optimizer_d",
    "scheduler_g",
    "scheduler_d",
}
missing = sorted(required.difference(checkpoint))
if missing:
    raise SystemExit(f"source checkpoint is incomplete; missing={missing}")
print(int(checkpoint["step"]))
PY
)"

if (( source_step < 76000 )); then
  echo "hpclong final checkpoint is unexpectedly old: step=$source_step" >&2
  exit 1
fi

mkdir -p "$N019_VOCODER_OUT"
source_sha256="$(sha256sum "$D6_SOURCE_CHECKPOINT" | awk '{print $1}')"
echo "source_step=$source_step source_sha256=$source_sha256"

# Copy only after hpclong has fully terminated, then verify the immutable copy.
cp --sparse=always "$D6_SOURCE_CHECKPOINT" "$TARGET_CHECKPOINT.tmp"
sync "$TARGET_CHECKPOINT.tmp"
mv "$TARGET_CHECKPOINT.tmp" "$TARGET_CHECKPOINT"
target_sha256="$(sha256sum "$TARGET_CHECKPOINT" | awk '{print $1}')"
if [[ "$target_sha256" != "$source_sha256" ]]; then
  echo "Checkpoint transfer SHA256 mismatch: source=$source_sha256 target=$target_sha256" >&2
  exit 1
fi

cat >"$N019_VOCODER_OUT/resume_source.json" <<EOF
{
  "source_run": "$D6_SOURCE_RUN",
  "source_checkpoint": "$D6_SOURCE_CHECKPOINT",
  "source_step": $source_step,
  "source_sha256": "$source_sha256",
  "target_checkpoint": "$TARGET_CHECKPOINT",
  "target_sha256": "$target_sha256",
  "selected_after_job": "1069636"
}
EOF

export N019_NPROC=1
export N019_VOCODER_TOTAL_BATCH=16
export N019_VOCODER_WORKERS=4
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RUN_NAME="$RUN_NAME"
export N019_VOCODER_RECORDS="/public/home/a094f4d4/voice_projects/data/n019_official/processed/units/libritts_train_clean_100/unit_records.jsonl"
export N019_VOCODER_EMBEDDINGS="/public/home/a094f4d4/voice_projects/data/n019_official/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz"
export N019_VOCODER_STEPS=400000
export N019_VOCODER_MAX_HOURS=42.25
export N019_VOCODER_CHECKPOINT_INTERVAL=2000
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL=2000
export N019_VOCODER_KEEP_INTERVAL=50000
export N019_VOCODER_VALIDATION_INTERVAL=2000
export N019_VOCODER_VALIDATION_LIMIT=64
export N019_VOCODER_SELECTION_POLICY=mos_offline
export N019_VOCODER_EARLY_STOP_PATIENCE=0
export N019_VOCODER_LR=2e-4
export N019_VOCODER_GRAD_CLIP_NORM=0.0
export N019_VOCODER_BF16=1
export N019_VOCODER_RESUME_SHA256="$target_sha256"
export N019_SKIP_PATH_VERIFY=1
export N019_TRAINING_DATA_MARKER="$N019_OFFICIAL_LOGS/d4_training_data_reference.json"
export N019_TRAINING_EXPECTED_ROWS=33236
export N019_STAGE_TRACE=1

bash "$N019_OFFICIAL_ROOT/scripts/run_vocoder_ddp.sh"
