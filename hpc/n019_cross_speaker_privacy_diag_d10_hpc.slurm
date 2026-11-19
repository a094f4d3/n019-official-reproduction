#!/bin/bash
#SBATCH --job-name=n019_crossspkdiag
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

source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

SOURCE="$HOME/voice_projects/data/n019_official/processed/selection_dev100_40spk/unit_records.jsonl"
TARGET_EMBEDDINGS="$HOME/voice_projects/data/n019_official/processed/embeddings/nt_ecapa_residual_test_20261117/residual_0p25.npz"
CANDIDATES="$HOME/voice_projects/runs/n019_official/vocoder_selection_crossspeaker_20261117/candidates"
OUT="$HOME/voice_projects/runs/n019_official/cross_speaker_target_shift_20261117"

test "$(wc -l < "$SOURCE")" = 100
test -s "$TARGET_EMBEDDINGS"
test "$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')" = "dc342ad39027937be3a6bb728ccb85f0026badda45cb95b764e33c7f92044122"
test -d "$CANDIDATES"
mkdir -p "$OUT"

bash "$N019_OFFICIAL_ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

for candidate in "$CANDIDATES"/*; do
  test -d "$candidate"
  manifest="$candidate/anonymised/anon.jsonl"
  test -s "$manifest" || continue
  name="$(basename "$candidate")"
  python -u -m n019.speaker_diagnostics \
    --source "$SOURCE" \
    --anon "$manifest" \
    --target-embeddings "$TARGET_EMBEDDINGS" \
    --model "$HOME/voice_projects/models/n019_official/wpro" \
    --out "$OUT/$name.json" \
    --device cuda
done

sha256sum "$OUT"/*.json
echo "N019_CROSS_SPEAKER_TARGET_SHIFT_COMPLETE out=$OUT"
