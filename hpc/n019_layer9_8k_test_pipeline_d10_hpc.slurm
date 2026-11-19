#!/bin/bash
#SBATCH --job-name=n019_layer9_8k_test
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

VOCODER="$HOME/voice_projects/runs/n019_official/vocoder_nt_layer9_aligned_pilot_20261116/snapshots/generator_step00008000.pt"
UNITS="$HOME/voice_projects/data/n019_official/processed/units/layer9_eval_20261116/test/unit_records.jsonl"
DURATION_MODEL="$HOME/voice_projects/runs/n019_official/duration_pred_layer9_aligned_20261116/best.pt"
OUT="$HOME/voice_projects/runs/n019_official/layer9_step8k_test_20261117"
SUFFIX=_n019_layer9_8k_20261117

test -s "$VOCODER"
test "$(wc -l < "$UNITS")" = 1934
test -s "$DURATION_MODEL"

export N019_LIBRI_TEST_SOURCE=/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/libri_test.jsonl
export N019_LIBRI_TEST_UNITS="$UNITS"
export N019_LIBRI_TEST_TARGET_MAP=/public/home/a094f4d6/voice_projects/data/n019_official/processed/targets/libri_test_target_map_paperfix.jsonl
export N019_LIBRI_TEST_TARGET_EMBEDDINGS="$OUT/target_speaker_mean32_shrink01_843.npz"
export N019_LIBRI_TEST_TARGET_EMBEDDING_KEY=target_speaker
export N019_LIBRI_TEST_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1
export N019_LIBRI_TEST_DURATION_MODE=pred
export N019_LIBRI_TEST_DURATION_MODEL="$DURATION_MODEL"
export N019_LIBRI_TEST_VOCODER="$VOCODER"
export N019_LIBRI_TEST_ANON_OUT="$OUT/anonymised"
export N019_LIBRI_TEST_SUFFIX="$SUFFIX"
export N019_LIBRI_TEST_VERIFY="$OUT/verification.json"
export N019_LIBRI_TEST_EXPECTED_SOURCE_SHA=d97cafa5790e69c41c14bda6d130148dc982933c22d2fccbdd421b0723e1c432
export N019_LIBRI_TEST_EXPECTED_DURATION_SHA=c84fe19ed8f9e31199ac6dd1926e2d565e8a4179c90f04411f55ced0c1191d5b
export N019_LIBRI_TEST_EXPECTED_VOCODER_SHA=39aeebe086700a3b18a29aa1f9ec354575b0a60aa86dc328c0a2ed2543559b66

bash scripts/gpu_tiny_matmul_watchdog.sh
bash scripts/anonymize_libri_test_paperfix_remote.sh

export N019_DATA_SUFFIX="$SUFFIX"
export N019_VPC_DATA="$N019_OFFICIAL_DATA/vpc/data"
export N019_WNT_BASE_VPC_DATA="$N019_VPC_DATA"
export N019_WNT_ATTACKS=L
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$OUT/wnt_l"
bash scripts/evaluate_wnt_remote.sh

sha256sum "$OUT/wnt_l/summary.json" "$OUT/verification.json"
echo "N019_LAYER9_8K_TEST_COMPLETE out=$OUT suffix=$SUFFIX"
