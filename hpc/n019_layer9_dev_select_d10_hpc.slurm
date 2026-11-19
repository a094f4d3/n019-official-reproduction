#!/bin/bash
#SBATCH --job-name=n019_layer9_sel
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=02:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

SNAP_DIR="${N019_LAYER9_PILOT_OUT:-$HOME/voice_projects/runs/n019_official/vocoder_nt_layer9_aligned_pilot_20261116}/snapshots"
DEV_UNITS="${N019_LAYER9_DEV_UNITS:-$HOME/voice_projects/data/n019_official/processed/units/layer9_eval_20261116/dev100/unit_records.jsonl}"
TARGET_MAP="${N019_LAYER9_DEV_TARGET_MAP:-/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_dev100_40spk_reused_target_map_seed20261102.jsonl}"
TARGET_EMBEDDINGS="${N019_LAYER9_DEV_TARGET_EMBEDDINGS:-/public/home/a094f4d6/voice_projects/tmp/n019_privacy_fix_20261111/target_speaker_mean32_all1158_shrink01.npz}"
DURATION_MODEL="${N019_LAYER9_DEV_DURATION_MODEL:-/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt}"
BASELINE_CHECKPOINT="${N019_LAYER9_DEV_BASELINE:-/public/home/a094f4d6/voice_projects/tmp/n019_privacy_fix_20261111/generator_soup2.pt}"
OUT="${N019_LAYER9_DEV_SELECT_OUT:-$HOME/voice_projects/runs/n019_official/vocoder_selection_layer9_20261116}"

test "$(wc -l < "$DEV_UNITS")" = 100
test -s "$TARGET_MAP"
test -s "$TARGET_EMBEDDINGS"
test -s "$DURATION_MODEL"
test -s "$BASELINE_CHECKPOINT"
test -d "$SNAP_DIR"

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
export N019_SELECTION_SNAPSHOT_GLOB='generator_step*.pt'
export N019_SELECTION_BASELINE_CHECKPOINT="$BASELINE_CHECKPOINT"
export N019_SELECTION_EARLY_REJECT_UTMOS=1
export N019_SELECTION_WHISPER_SMALL_PATH="$HOME/voice_projects/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d"
export N019_SELECTION_ASR_MODEL="$HOME/voice_projects/models/n019_official/vpc_asr_local/asr_n019_local"

bash scripts/run_vocoder_snapshot_selection_ai.sh
echo "N019_LAYER9_DEV_SELECT_COMPLETE out=$OUT"
