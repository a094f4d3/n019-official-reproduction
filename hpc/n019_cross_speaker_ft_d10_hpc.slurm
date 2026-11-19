#!/bin/bash
#SBATCH --job-name=n019_crossspk
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

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

FULL_STATE="/public/home/a094f4d5/voice_projects/runs/n019_official/vocoder_nt_hpc_d5_hpclongfinal_20261110/last.pt"
FULL_STATE_SHA="89768a4b94a7a326c02eeaf216022df2341abe36312149b6dac18c5048558c23"
GENERATOR="$HOME/voice_projects/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt"
GENERATOR_SHA="ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"
RECORDS="/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/libritts_train_clean_100/unit_records.jsonl"
EMBEDDINGS="$HOME/voice_projects/data/n019_official/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz"
SWAP_EMBEDDINGS="$HOME/voice_projects/data/n019_official/processed/embeddings/nt_ecapa_residual_all1158_20261117/residual_0p25.npz"
SWAP_EMBEDDINGS_SHA="82db74b116f6a4ae58dd1fdf6c8ab1c5accc8b179c63e33a0453addfcf067831"
MARKER="/public/home/a094f4d6/voice_projects/logs/n019_official/d6_training_data_ready.json"
OUT="$HOME/voice_projects/runs/n019_official/vocoder_nt_crossspeaker_ft_20261117"

test -s "$FULL_STATE"
test -s "$GENERATOR"
test -s "$RECORDS"
test -s "$EMBEDDINGS"
test -s "$SWAP_EMBEDDINGS"
test -s "$MARKER"
test "$(sha256sum "$GENERATOR" | awk '{print $1}')" = "$GENERATOR_SHA"
test "$(sha256sum "$SWAP_EMBEDDINGS" | awk '{print $1}')" = "$SWAP_EMBEDDINGS_SHA"

if [[ -e "$OUT/last.pt" ]]; then
  echo "Refusing to overwrite existing checkpoint: $OUT/last.pt" >&2
  exit 1
fi
mkdir -p "$OUT"

echo "user=$(id -un) host=$(hostname) date=$(date -Is) job=${SLURM_JOB_ID}"
echo "purpose=source-target speaker conditioning disentanglement fine-tune"
echo "full_state=$FULL_STATE sha256=$FULL_STATE_SHA"
echo "generator=$GENERATOR sha256=$GENERATOR_SHA"
echo "swap_embeddings=$SWAP_EMBEDDINGS sha256=$SWAP_EMBEDDINGS_SHA"
echo "out=$OUT"
echo "wall=2h expected=0.8 worst=2.0 card-hours"

python "$ROOT/scripts/build_cross_speaker_finetune_checkpoint.py" \
  --full-state "$FULL_STATE" \
  --full-state-sha256 "$FULL_STATE_SHA" \
  --generator "$GENERATOR" \
  --generator-sha256 "$GENERATOR_SHA" \
  --lr 5e-5 \
  --speaker-swap-probability 0.5 \
  --out "$OUT/last.pt" \
  | tee "$OUT/initialization.json"

RESUME_SHA="$(sha256sum "$OUT/last.pt" | awk '{print $1}')"
echo "cross_speaker_checkpoint=$OUT/last.pt sha256=$RESUME_SHA"

export N019_NPROC=1
export N019_VOCODER_TOTAL_BATCH=16
export N019_VOCODER_WORKERS=4
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RUN_NAME="$(basename "$OUT")"
export N019_VOCODER_OUT="$OUT"
export N019_VOCODER_STEPS=4000
export N019_VOCODER_MAX_HOURS=1.75
export N019_VOCODER_CHECKPOINT_INTERVAL=1000
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL=1000
export N019_VOCODER_KEEP_INTERVAL=10000
export N019_VOCODER_VALIDATION_INTERVAL=1000
export N019_VOCODER_VALIDATION_LIMIT=32
export N019_VOCODER_SELECTION_POLICY=mos_offline
export N019_VOCODER_EARLY_STOP_MIN_STEPS=4000
export N019_VOCODER_EARLY_STOP_PATIENCE=0
export N019_VOCODER_LR=5e-5
export N019_VOCODER_OPTIMIZER=adamw
export N019_VOCODER_GRAD_CLIP_NORM=0.0
export N019_VOCODER_BF16=1
export N019_VOCODER_SPEAKER_SWAP_PROBABILITY=0.5
export N019_VOCODER_SPEAKER_SWAP_EMBEDDINGS="$SWAP_EMBEDDINGS"
export N019_VOCODER_ALLOW_RECIPE_CHANGE=1
export N019_VOCODER_RESUME_SHA256="$RESUME_SHA"
export N019_VOCODER_RECORDS="$RECORDS"
export N019_VOCODER_EMBEDDINGS="$EMBEDDINGS"
export N019_SKIP_PATH_VERIFY=1
export N019_TRAINING_DATA_MARKER="$MARKER"
export N019_TRAINING_EXPECTED_ROWS=33236
export N019_STAGE_TRACE=1

bash "$ROOT/scripts/run_vocoder_ddp.sh"

sha256sum \
  "$OUT"/snapshots/generator_step*.pt \
  "$OUT/last.pt" \
  "$OUT/meta.json" \
  "$OUT/initialization.json"
echo "N019_CROSS_SPEAKER_FINETUNE_COMPLETE out=$OUT"
