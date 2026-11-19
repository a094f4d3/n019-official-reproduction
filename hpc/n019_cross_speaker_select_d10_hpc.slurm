#!/bin/bash
#SBATCH --job-name=n019_crossspksel
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

SNAP_DIR="$HOME/voice_projects/runs/n019_official/vocoder_nt_crossspeaker_ft_20261117/snapshots"
DEV_UNITS="$HOME/voice_projects/data/n019_official/processed/selection_dev100_40spk/unit_records.jsonl"
TARGET_MAP="/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_dev100_40spk_reused_target_map_seed20261102.jsonl"
TARGET_EMBEDDINGS="$HOME/voice_projects/data/n019_official/processed/embeddings/nt_ecapa_residual_test_20261117/residual_0p25.npz"
DURATION_MODEL="$HOME/voice_projects/data/n019_official/processed/selection_dev100_40spk/duration_pred_paperfix_best.pt"
BASELINE_CHECKPOINT="$HOME/voice_projects/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt"
OUT="$HOME/voice_projects/runs/n019_official/vocoder_selection_crossspeaker_20261117"

test "$(wc -l < "$DEV_UNITS")" = 100
test "$(sha256sum "$DEV_UNITS" | awk '{print $1}')" = "249aa5c2f551cdc4b1921939ab70d55816170f01f51d2b83b08ca26029fdad92"
test -s "$TARGET_MAP"
test "$(sha256sum "$TARGET_MAP" | awk '{print $1}')" = "f8cc5b8b7b56e6393a05eae360bc7736e29ea77a0fd54e78c4220795fdb72627"
test -s "$TARGET_EMBEDDINGS"
test "$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')" = "dc342ad39027937be3a6bb728ccb85f0026badda45cb95b764e33c7f92044122"
test -s "$DURATION_MODEL"
test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = "8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c"
test -s "$BASELINE_CHECKPOINT"
test "$(sha256sum "$BASELINE_CHECKPOINT" | awk '{print $1}')" = "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
test -d "$SNAP_DIR"

export N019_SELECTION_OUT="$OUT"
export N019_SELECTION_MODE=target_anonymisation
export N019_SELECTION_LIMIT=100
export N019_SELECTION_SOURCE_MANIFEST="$DEV_UNITS"
export N019_SELECTION_UNIT_RECORDS="$DEV_UNITS"
export N019_SELECTION_TARGET_MAP="$TARGET_MAP"
export N019_SELECTION_VOCODER_EMBEDDINGS="$TARGET_EMBEDDINGS"
export N019_SELECTION_TARGET_EMBEDDING_KEY=target_speaker
export N019_SELECTION_TARGET_EMBEDDING_MODE=speaker_mean_l2
export N019_SELECTION_DURATION_MODEL="$DURATION_MODEL"
export N019_SELECTION_SNAPSHOT_DIR="$SNAP_DIR"
export N019_SELECTION_SNAPSHOT_GLOB='generator_step*.pt'
export N019_SELECTION_BASELINE_CHECKPOINT="$BASELINE_CHECKPOINT"
export N019_SELECTION_EARLY_REJECT_UTMOS=1
export N019_SELECTION_WHISPER_SMALL_PATH="$HOME/voice_projects/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d"
export N019_SELECTION_ASR_MODEL="$HOME/voice_projects/models/n019_official/vpc_asr_local/asr_n019_local"

bash scripts/run_vocoder_snapshot_selection_ai.sh
echo "N019_CROSS_SPEAKER_SELECT_COMPLETE out=$OUT"
