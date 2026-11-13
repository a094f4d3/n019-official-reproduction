#!/bin/bash
#SBATCH --job-name=n019_vocd6_cont34h
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=34:15:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

export N019_OFFICIAL_ROOT="$HOME/voice_projects/code/n019_official_lr2e4_resume"
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

export N019_VOCODER_OUT="$N019_OFFICIAL_RUNS/vocoder_nt_hpc_ft14k_long_20261109"

echo "user=$(id -un) host=$(hostname) date=$(date -Is) job=${SLURM_JOB_ID}"
echo "mode=HPC continuation dcu=1 total_batch=16 budget=34.0h precision=bf16"
echo "output=$N019_VOCODER_OUT"

if [[ ! -f "$N019_VOCODER_OUT/last.pt" ]]; then
  echo "Missing d6 continuation checkpoint: $N019_VOCODER_OUT/last.pt" >&2
  exit 1
fi

checkpoint_step="$(
  python - "$N019_VOCODER_OUT/last.pt" <<'PY'
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
    raise SystemExit(f"d6 checkpoint is incomplete; missing={missing}")
print(int(checkpoint["step"]))
PY
)"

if (( checkpoint_step < 78000 )); then
  echo "d6 continuation checkpoint is unexpectedly old: step=$checkpoint_step" >&2
  exit 1
fi

resume_sha256="$(sha256sum "$N019_VOCODER_OUT/last.pt" | awk '{print $1}')"
cat >"$N019_VOCODER_OUT/continuation_${SLURM_JOB_ID}.json" <<EOF
{
  "checkpoint": "$N019_VOCODER_OUT/last.pt",
  "step": $checkpoint_step,
  "sha256": "$resume_sha256",
  "budget_hours": 34.0,
  "depends_on_job": "1069636"
}
EOF
echo "resume_step=$checkpoint_step resume_sha256=$resume_sha256"

export N019_NPROC=1
export N019_VOCODER_TOTAL_BATCH=16
export N019_VOCODER_WORKERS=4
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RUN_NAME="vocoder_nt_hpc_ft14k_long"
export N019_VOCODER_STEPS=400000
export N019_VOCODER_MAX_HOURS=34.0
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
export N019_VOCODER_RESUME_SHA256="$resume_sha256"
export N019_SKIP_PATH_VERIFY=1
export N019_TRAINING_DATA_MARKER="$N019_OFFICIAL_LOGS/d6_training_data_ready.json"
export N019_TRAINING_EXPECTED_ROWS=33236
export N019_STAGE_TRACE=1

bash "$N019_OFFICIAL_ROOT/scripts/run_vocoder_ddp.sh"
