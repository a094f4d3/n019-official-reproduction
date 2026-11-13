#!/bin/bash
#SBATCH --job-name=n019_du_nt_smoke
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=dcu:1
#SBATCH --mem=30G
#SBATCH --time=00:20:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

BASE="$N019_OFFICIAL_DATA"
STAGED="$BASE/processed/targets/du_nt_nt_20261111"
OUT="${N019_SMOKE_OUT:-$N019_OFFICIAL_RUNS/privacy/du_nt_nt_smoke_${SLURM_JOB_ID}}"
mkdir -p "$OUT"

head -4 "$BASE/processed/manifests/libri_test.jsonl" > "$OUT/source.jsonl"
head -4 "$BASE/processed/units/libri_test_paperfix/unit_records.jsonl" > "$OUT/units.jsonl"
head -4 "$STAGED/libri_test_target_map.jsonl" > "$OUT/target_map.jsonl"

if ! timeout --signal=KILL 300s python -c \
  "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
  echo "DCU watchdog failed" >&2
  exit 124
fi

python -u -m n019.anonymize \
  --source-manifest "$OUT/source.jsonl" \
  --unit-records "$OUT/units.jsonl" \
  --target-map "$OUT/target_map.jsonl" \
  --duration-mode nt \
  --duration-model "$N019_OFFICIAL_RUNS/duration_nt_main/best.pt" \
  --duration-embeddings "$STAGED/target_speaker_mean32_all1158_shrink01.npz" \
  --duration-embedding-key target_speaker \
  --vocoder "$HOME/voice_projects/tmp/n019_privacy_fix_20261111/generator_soup2.pt" \
  --vocoder-type nt \
  --vocoder-embeddings "$STAGED/target_speaker_mean32_all1158_shrink01.npz" \
  --target-embedding-key target_speaker \
  --target-embedding-mode speaker_mean_l2_shrink0.1 \
  --out-dir "$OUT/anonymised" \
  --device cuda

test "$(find "$OUT/anonymised" -maxdepth 1 -type f -name '*.wav' | wc -l)" = 4
test "$(wc -l < "$OUT/anonymised/anon.jsonl")" = 4
sha256sum "$OUT/anonymised/anon.jsonl" "$OUT/anonymised/run_meta.json"
echo "DU_NT_NT_SMOKE_COMPLETE out=$OUT"
