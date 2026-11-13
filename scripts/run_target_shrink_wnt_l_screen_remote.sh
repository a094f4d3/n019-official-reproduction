#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

OUT_ROOT="${N019_SHRINK_SCREEN_OUT:?Set N019_SHRINK_SCREEN_OUT}"
RUNNER="$ROOT/scripts/run_speaker_sampling_wnt_l_remote.sh"
TARGET_MAP="${N019_SHRINK_SCREEN_TARGET_MAP:-$N019_OFFICIAL_RUNS/target_sampling_diag_20261111/libri_test_target_map_speaker_available_seed20261102.jsonl}"
VOCODER="${N019_SHRINK_SCREEN_VOCODER:-/public/home/a094f4d7/voice_projects/tmp/n019_model_soup_round2_candidates_20261110/generator_avg_soup2_quad_w40_30_20_10.pt}"
VOCODER_SHA="${N019_SHRINK_SCREEN_VOCODER_SHA:-ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6}"
EMBEDDING_ROOT="${N019_SHRINK_SCREEN_EMBEDDING_ROOT:-/public/home/a094f4d7/voice_projects/tmp/n019_target_shrink_ab_20261111}"
WEIGHTS="${N019_SHRINK_SCREEN_WEIGHTS:-0 0.05}"

for required in \
  "$RUNNER" \
  "$TARGET_MAP" \
  "$VOCODER"; do
  test -f "$required" || {
    echo "Missing target-shrink screen input: $required" >&2
    exit 1
  }
done
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "$VOCODER_SHA"

mkdir -p "$OUT_ROOT"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "user=$(id -un)"
  echo "date=$(date -Is)"
  echo "out_root=$OUT_ROOT"
  echo "target_map=$TARGET_MAP"
  echo "vocoder=$VOCODER"
  echo "vocoder_sha256=$VOCODER_SHA"
  echo "embedding_root=$EMBEDDING_ROOT"
  echo "shrink_weights=$WEIGHTS"
} | tee "$OUT_ROOT/launch.txt"

for weight in $WEIGHTS; do
  tag="$(python - "$weight" <<'PY'
import sys
print(f"{float(sys.argv[1]):.2f}".replace(".", ""))
PY
)"
  embeddings="$EMBEDDING_ROOT/nt_speaker_embeddings_shrink${tag}.npz"
  test -f "$embeddings" || {
    echo "Missing shrink embedding: $embeddings" >&2
    exit 1
  }
  embeddings_sha="$(sha256sum "$embeddings" | awk '{print $1}')"
  run_root="$OUT_ROOT/shrink_${tag}"
  mkdir -p "$run_root"

  N019_SPKSAMPLE_RUN_ROOT="$run_root" \
  N019_SPKSAMPLE_SUFFIX="_n019_shrinkscreen_${tag}_20261111" \
  N019_SPKSAMPLE_VOCODER="$VOCODER" \
  N019_SPKSAMPLE_VOCODER_SHA="$VOCODER_SHA" \
  N019_SPKSAMPLE_TARGET_MAP="$TARGET_MAP" \
  N019_SPKSAMPLE_SPEAKER_EMBEDDINGS="$embeddings" \
  N019_SPKSAMPLE_SPEAKER_EMBEDDINGS_SHA="$embeddings_sha" \
    bash "$RUNNER"
done

python - "$OUT_ROOT" "$WEIGHTS" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
weights = [float(value) for value in sys.argv[2].split()]
rows = []
for weight in weights:
    tag = f"{weight:.2f}".replace(".", "")
    run_root = root / f"shrink_{tag}"
    comparison_path = run_root / "speaker_sampling_wnt_l_comparison.json"
    comparison = json.loads(comparison_path.read_text(encoding="utf-8"))
    attack = comparison["speaker_sampled_mean32_wnt_l"]
    rows.append(
        {
            "shrink_weight": weight,
            "embedding_sha256": comparison["embedding_sha256"],
            "wnt_l_female_eer_percent": attack["female_eer_percent"],
            "wnt_l_male_eer_percent": attack["male_eer_percent"],
            "wnt_l_mean_eer_percent": attack["mean_eer_percent"],
            "summary_sha256": comparison["summary_sha256"],
        }
    )

result = {
    "paper_wnt_l_eer_percent": 42.3,
    "formal_shrink01_wnt_l_eer_percent": 40.3585813940,
    "rows": rows,
}
(root / "target_shrink_wnt_l_screen.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$OUT_ROOT/target_shrink_wnt_l_screen.json" \
  "$OUT_ROOT"/shrink_*/speaker_sampling_wnt_l_comparison.json \
  "$OUT_ROOT"/shrink_*/wnt/summary.json
echo "TARGET_SHRINK_WNT_L_SCREEN_COMPLETE out=$OUT_ROOT"
