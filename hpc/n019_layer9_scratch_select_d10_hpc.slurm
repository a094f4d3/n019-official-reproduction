#!/bin/bash
#SBATCH --job-name=n019_l9scrsel
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=03:00:00
#SBATCH --exclude=f11r1n01,f11r2n13
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
export TMPDIR="/dev/shm/n019_l9scrsel_${SLURM_JOB_ID:-manual}"
mkdir -p "$TMPDIR"

DEV_UNITS="$HOME/voice_projects/data/n019_official/processed/units/layer9_eval_20261116/dev100/unit_records.jsonl"
TARGET_MAP="/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_dev100_40spk_reused_target_map_seed20261102.jsonl"
TARGET_EMBEDDINGS="/public/home/a094f4d6/voice_projects/tmp/n019_privacy_fix_20261111/target_speaker_mean32_all1158_shrink01.npz"
DURATION_MODEL="$N019_OFFICIAL_RUNS/duration_pred_layer9_aligned_20261116/best.pt"
SNAP_DIR="$N019_OFFICIAL_RUNS/vocoder_nt_layer9_aligned_scratch_20261117/snapshots"
BASELINE="$N019_OFFICIAL_RUNS/vocoder_nt_layer9_aligned_pilot_20261116/snapshots/generator_step00020000.pt"
OUT="$N019_OFFICIAL_RUNS/vocoder_selection_layer9_scratch_20261117"

test "$(wc -l < "$DEV_UNITS")" = 100
for required in "$TARGET_MAP" "$TARGET_EMBEDDINGS" "$DURATION_MODEL" "$BASELINE"; do
  test -s "$required" || {
    echo "Missing layer-9 scratch selection input: $required" >&2
    exit 1
  }
done

export N019_SELECTION_OUT="$OUT"
export N019_SELECTION_MODE=target_anonymisation
export N019_SELECTION_LIMIT=100
export N019_SELECTION_SOURCE_MANIFEST="$DEV_UNITS"
export N019_SELECTION_UNIT_RECORDS="$DEV_UNITS"
export N019_SELECTION_TARGET_MAP="$TARGET_MAP"
export N019_SELECTION_VOCODER_EMBEDDINGS="$TARGET_EMBEDDINGS"
export N019_SELECTION_TARGET_EMBEDDING_KEY=target_speaker
export N019_SELECTION_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1
export N019_SELECTION_DURATION_MODEL="$DURATION_MODEL"
export N019_SELECTION_SNAPSHOT_DIR="$SNAP_DIR"
export N019_SELECTION_SNAPSHOT_GLOB='generator_step00[0-1][0-9][0-9]000.pt'
export N019_SELECTION_BASELINE_CHECKPOINT="$BASELINE"
export N019_SELECTION_EARLY_REJECT_UTMOS=1
export N019_SELECTION_WHISPER_SMALL_PATH="$HOME/voice_projects/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d"
export N019_SELECTION_ASR_MODEL="$HOME/voice_projects/models/n019_official/vpc_asr_local/asr_n019_local"

bash scripts/run_vocoder_snapshot_selection_ai.sh
echo "N019_LAYER9_SCRATCH_SELECT_COMPLETE out=$OUT"
