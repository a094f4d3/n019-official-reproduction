#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

OUT_ROOT="${N019_SEED_SCREEN_OUT:?Set N019_SEED_SCREEN_OUT}"
TARGET_MAP_DIR="${N019_SEED_SCREEN_TARGET_MAP_DIR:?Set N019_SEED_SCREEN_TARGET_MAP_DIR}"
EMBEDDINGS="${N019_SEED_SCREEN_EMBEDDINGS:?Set N019_SEED_SCREEN_EMBEDDINGS}"
EMBEDDINGS_SHA="${N019_SEED_SCREEN_EMBEDDINGS_SHA:?Set N019_SEED_SCREEN_EMBEDDINGS_SHA}"
RUNNER="$ROOT/scripts/run_speaker_sampling_wnt_l_remote.sh"
VOCODER="${N019_SEED_SCREEN_VOCODER:-/public/home/a094f4d7/voice_projects/tmp/n019_model_soup_round2_candidates_20261110/generator_avg_soup2_quad_w40_30_20_10.pt}"
VOCODER_SHA="${N019_SEED_SCREEN_VOCODER_SHA:-ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6}"
SEEDS="${N019_SEED_SCREEN_SEEDS:-20261103 20261104 20261105}"

test -f "$RUNNER"
test -f "$EMBEDDINGS"
test "$(sha256sum "$EMBEDDINGS" | awk '{print $1}')" = "$EMBEDDINGS_SHA"
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "$VOCODER_SHA"

mkdir -p "$OUT_ROOT"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "user=$(id -un)"
  echo "date=$(date -Is)"
  echo "out_root=$OUT_ROOT"
  echo "target_map_dir=$TARGET_MAP_DIR"
  echo "embeddings=$EMBEDDINGS"
  echo "embeddings_sha256=$EMBEDDINGS_SHA"
  echo "vocoder=$VOCODER"
  echo "vocoder_sha256=$VOCODER_SHA"
  echo "seeds=$SEEDS"
} | tee "$OUT_ROOT/launch.txt"

for seed in $SEEDS; do
  target_map="$TARGET_MAP_DIR/libri_test_target_map_speaker_available_seed${seed}.jsonl"
  test -f "$target_map" || {
    echo "Missing target map: $target_map" >&2
    exit 1
  }
  run_root="$OUT_ROOT/seed_${seed}"
  mkdir -p "$run_root"
  sha256sum "$target_map" > "$run_root/target_map.sha256"

  N019_SPKSAMPLE_RUN_ROOT="$run_root" \
  N019_SPKSAMPLE_SUFFIX="_n019_seedscreen_${seed}_20261111" \
  N019_SPKSAMPLE_VOCODER="$VOCODER" \
  N019_SPKSAMPLE_VOCODER_SHA="$VOCODER_SHA" \
  N019_SPKSAMPLE_TARGET_MAP="$target_map" \
  N019_SPKSAMPLE_SPEAKER_EMBEDDINGS="$EMBEDDINGS" \
  N019_SPKSAMPLE_SPEAKER_EMBEDDINGS_SHA="$EMBEDDINGS_SHA" \
    bash "$RUNNER"
done

python - "$OUT_ROOT" "$SEEDS" <<'PY'
import hashlib
import json
import statistics
import sys
from pathlib import Path

root = Path(sys.argv[1])
seeds = [int(value) for value in sys.argv[2].split()]
rows = []
for seed in seeds:
    run_root = root / f"seed_{seed}"
    comparison_path = run_root / "speaker_sampling_wnt_l_comparison.json"
    comparison = json.loads(comparison_path.read_text(encoding="utf-8"))
    attack = comparison["speaker_sampled_mean32_wnt_l"]
    map_sha = (run_root / "target_map.sha256").read_text(
        encoding="utf-8"
    ).split()[0]
    rows.append(
        {
            "seed": seed,
            "target_map_sha256": map_sha,
            "wnt_l_female_eer_percent": attack["female_eer_percent"],
            "wnt_l_male_eer_percent": attack["male_eer_percent"],
            "wnt_l_mean_eer_percent": attack["mean_eer_percent"],
            "summary_sha256": comparison["summary_sha256"],
        }
    )

means = [row["wnt_l_mean_eer_percent"] for row in rows]
result = {
    "paper_wnt_l_eer_percent": 42.3,
    "rows": rows,
    "mean": statistics.mean(means),
    "population_stddev": statistics.pstdev(means),
    "min": min(means),
    "max": max(means),
}
(root / "seed_wnt_l_screen.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$OUT_ROOT/seed_wnt_l_screen.json" \
  "$OUT_ROOT"/seed_*/target_map.sha256 \
  "$OUT_ROOT"/seed_*/speaker_sampling_wnt_l_comparison.json \
  "$OUT_ROOT"/seed_*/wnt/summary.json
echo "TARGET_SEED_WNT_L_SCREEN_COMPLETE out=$OUT_ROOT"
