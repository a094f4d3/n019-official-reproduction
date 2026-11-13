#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

OUT_ROOT="${N019_PRIVACY_SOUP_SCREEN_OUT:?Set N019_PRIVACY_SOUP_SCREEN_OUT}"
CHECKPOINT_ROOT="${N019_PRIVACY_SOUP_CHECKPOINT_ROOT:?Set N019_PRIVACY_SOUP_CHECKPOINT_ROOT}"
RUNNER="$ROOT/scripts/run_speaker_sampling_wnt_l_remote.sh"
TARGET_MAP="${N019_PRIVACY_SOUP_TARGET_MAP:-$N019_OFFICIAL_RUNS/target_sampling_diag_20261111/libri_test_target_map_speaker_available_seed20261102.jsonl}"
EMBEDDINGS="${N019_PRIVACY_SOUP_EMBEDDINGS:-/public/home/a094f4d7/voice_projects/tmp/n019_target_shrink_ab_20261111/nt_speaker_embeddings_shrink000.npz}"
EMBEDDINGS_SHA="${N019_PRIVACY_SOUP_EMBEDDINGS_SHA:-3c2fc06cb591b3abea8b2c6017f82cb178a949fa4146caaf6caed84fd8c33147}"
CASES="${N019_PRIVACY_SOUP_CASES:-96heavy_10_20_20_50 92_96_equal}"

for required in \
  "$RUNNER" \
  "$TARGET_MAP" \
  "$EMBEDDINGS"; do
  test -f "$required" || {
    echo "Missing privacy-soup input: $required" >&2
    exit 1
  }
done
test "$(sha256sum "$EMBEDDINGS" | awk '{print $1}')" = "$EMBEDDINGS_SHA"

mkdir -p "$OUT_ROOT"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "user=$(id -un)"
  echo "date=$(date -Is)"
  echo "out_root=$OUT_ROOT"
  echo "checkpoint_root=$CHECKPOINT_ROOT"
  echo "target_map=$TARGET_MAP"
  echo "embeddings=$EMBEDDINGS"
  echo "embeddings_sha256=$EMBEDDINGS_SHA"
  echo "cases=$CASES"
} | tee "$OUT_ROOT/launch.txt"

for name in $CASES; do
  checkpoint="$CHECKPOINT_ROOT/generator_avg_${name}.pt"
  test -f "$checkpoint" || {
    echo "Missing privacy-soup checkpoint: $checkpoint" >&2
    exit 1
  }
  checkpoint_sha="$(sha256sum "$checkpoint" | awk '{print $1}')"
  run_root="$OUT_ROOT/$name"
  mkdir -p "$run_root"
  printf '%s  %s\n' "$checkpoint_sha" "$checkpoint" \
    > "$run_root/checkpoint.sha256"

  N019_SPKSAMPLE_RUN_ROOT="$run_root" \
  N019_SPKSAMPLE_SUFFIX="_n019_privsoup_${name}_20261111" \
  N019_SPKSAMPLE_VOCODER="$checkpoint" \
  N019_SPKSAMPLE_VOCODER_SHA="$checkpoint_sha" \
  N019_SPKSAMPLE_TARGET_MAP="$TARGET_MAP" \
  N019_SPKSAMPLE_SPEAKER_EMBEDDINGS="$EMBEDDINGS" \
  N019_SPKSAMPLE_SPEAKER_EMBEDDINGS_SHA="$EMBEDDINGS_SHA" \
    bash "$RUNNER"
done

python - "$OUT_ROOT" "$CASES" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
cases = sys.argv[2].split()
rows = []
for name in cases:
    run_root = root / name
    comparison_path = run_root / "speaker_sampling_wnt_l_comparison.json"
    comparison = json.loads(comparison_path.read_text(encoding="utf-8"))
    attack = comparison["speaker_sampled_mean32_wnt_l"]
    checkpoint_sha = (run_root / "checkpoint.sha256").read_text(
        encoding="utf-8"
    ).split()[0]
    rows.append(
        {
            "name": name,
            "checkpoint_sha256": checkpoint_sha,
            "wnt_l_female_eer_percent": attack["female_eer_percent"],
            "wnt_l_male_eer_percent": attack["male_eer_percent"],
            "wnt_l_mean_eer_percent": attack["mean_eer_percent"],
            "summary_sha256": comparison["summary_sha256"],
        }
    )

result = {
    "paper_wnt_l_eer_percent": 42.3,
    "formal_soup_shrink01_wnt_l_eer_percent": 40.3585813940,
    "formal_soup_shrink00_wnt_l_eer_percent": 41.24317988753319,
    "rows": rows,
}
(root / "privacy_soup_wnt_l_screen.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$OUT_ROOT/privacy_soup_wnt_l_screen.json" \
  "$OUT_ROOT"/*/checkpoint.sha256 \
  "$OUT_ROOT"/*/speaker_sampling_wnt_l_comparison.json \
  "$OUT_ROOT"/*/wnt/summary.json
echo "PRIVACY_SOUP_WNT_L_SCREEN_COMPLETE out=$OUT_ROOT"
