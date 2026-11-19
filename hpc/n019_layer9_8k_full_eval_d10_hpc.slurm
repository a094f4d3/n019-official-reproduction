#!/bin/bash
#SBATCH --job-name=n019_layer9_8k_eval
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=03:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

OUT="$HOME/voice_projects/runs/n019_official/layer9_step8k_test_20261117"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_EVAL_LABEL=layer9_8k_20261117
export N019_EVAL_STEPS=8000
export N019_EVAL_VOCODER="$HOME/voice_projects/runs/n019_official/vocoder_nt_layer9_aligned_pilot_20261116/snapshots/generator_step00008000.pt"
export N019_EVAL_VOC_SHA=39aeebe086700a3b18a29aa1f9ec354575b0a60aa86dc328c0a2ed2543559b66
export N019_EVAL_TARGET_EMBEDDINGS="$OUT/target_speaker_mean32_shrink01_843.npz"
export N019_EVAL_TARGET_EMBEDDING_KEY=target_speaker
export N019_EVAL_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1
export N019_EVAL_ANON_OUT="$OUT/anonymised"
export N019_EVAL_OUT="$OUT/eval"

bash scripts/run_full_eval_param_ai.sh
sha256sum \
  "$OUT/eval/WER.json" \
  "$OUT/eval/mos/UTMOS.json" \
  "$OUT/eval/mos/WhiSQA.json" \
  "$OUT/eval/quality_metrics.json"
echo "N019_LAYER9_8K_FULL_EVAL_COMPLETE out=$OUT/eval"
