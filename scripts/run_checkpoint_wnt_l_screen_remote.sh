#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

OUT_ROOT="${N019_WNT_SCREEN_OUT:?Set N019_WNT_SCREEN_OUT}"
SNAPSHOT_ROOT="${N019_WNT_SCREEN_SNAPSHOT_ROOT:?Set N019_WNT_SCREEN_SNAPSHOT_ROOT}"
TARGET_MAP="${N019_WNT_SCREEN_TARGET_MAP:-$N019_OFFICIAL_RUNS/target_sampling_diag_20261111/libri_test_target_map_speaker_available_seed20261102.jsonl}"
SPEAKER_EMBEDDINGS="${N019_WNT_SCREEN_SPEAKER_EMBEDDINGS:-$N019_OFFICIAL_DATA/processed/embeddings/target_speaker_mean32_all1158_shrink01_20261110.npz}"
SPEAKER_EMBEDDINGS_SHA="${N019_WNT_SCREEN_SPEAKER_EMBEDDINGS_SHA:-28ffbaec9516cd8f5abbc752b40315b9fe958f7d37dc6b6f4a58bcd28c2540a7}"
STEPS="${N019_WNT_SCREEN_STEPS:-84000 88000 92000 96000}"
STEPS="${STEPS//,/ }"
RUNNER="$ROOT/scripts/run_speaker_sampling_wnt_l_remote.sh"

for required in \
  "$RUNNER" \
  "$TARGET_MAP" \
  "$SPEAKER_EMBEDDINGS"; do
  test -f "$required" || {
    echo "Missing W-NT checkpoint-screen input: $required" >&2
    exit 1
  }
done
test "$(sha256sum "$SPEAKER_EMBEDDINGS" | awk '{print $1}')" = \
  "$SPEAKER_EMBEDDINGS_SHA"

mkdir -p "$OUT_ROOT"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "user=$(id -un)"
  echo "date=$(date -Is)"
  echo "out_root=$OUT_ROOT"
  echo "snapshot_root=$SNAPSHOT_ROOT"
  echo "target_map=$TARGET_MAP"
  echo "speaker_embeddings=$SPEAKER_EMBEDDINGS"
  echo "speaker_embeddings_sha256=$SPEAKER_EMBEDDINGS_SHA"
  echo "steps=$STEPS"
} | tee "$OUT_ROOT/launch.txt"

for step in $STEPS; do
  padded="$(printf '%08d' "$step")"
  checkpoint="$SNAPSHOT_ROOT/generator_step${padded}.pt"
  test -f "$checkpoint" || {
    echo "Missing checkpoint: $checkpoint" >&2
    exit 1
  }
  checkpoint_sha="$(sha256sum "$checkpoint" | awk '{print $1}')"
  run_root="$OUT_ROOT/step_${step}"
  mkdir -p "$run_root"
  printf '%s  %s\n' "$checkpoint_sha" "$checkpoint" \
    > "$run_root/checkpoint.sha256"

  N019_SPKSAMPLE_RUN_ROOT="$run_root" \
  N019_SPKSAMPLE_SUFFIX="_n019_wntscreen_${step}_20261111" \
  N019_SPKSAMPLE_VOCODER="$checkpoint" \
  N019_SPKSAMPLE_VOCODER_SHA="$checkpoint_sha" \
  N019_SPKSAMPLE_TARGET_MAP="$TARGET_MAP" \
  N019_SPKSAMPLE_SPEAKER_EMBEDDINGS="$SPEAKER_EMBEDDINGS" \
  N019_SPKSAMPLE_SPEAKER_EMBEDDINGS_SHA="$SPEAKER_EMBEDDINGS_SHA" \
    bash "$RUNNER"
done

python - "$OUT_ROOT" "$STEPS" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
steps = [int(value) for value in sys.argv[2].split()]
rows = []
for step in steps:
    run_root = root / f"step_{step}"
    comparison_path = run_root / "speaker_sampling_wnt_l_comparison.json"
    checkpoint_path = run_root / "checkpoint.sha256"
    comparison = json.loads(comparison_path.read_text(encoding="utf-8"))
    checkpoint_sha = checkpoint_path.read_text(encoding="utf-8").split()[0]
    attack = comparison["speaker_sampled_mean32_wnt_l"]
    rows.append(
        {
            "step": step,
            "checkpoint_sha256": checkpoint_sha,
            "wnt_l_female_eer_percent": attack["female_eer_percent"],
            "wnt_l_male_eer_percent": attack["male_eer_percent"],
            "wnt_l_mean_eer_percent": attack["mean_eer_percent"],
            "comparison_sha256": hashlib.sha256(
                comparison_path.read_bytes()
            ).hexdigest(),
        }
    )

result = {
    "paper_wnt_l_eer_percent": 42.3,
    "formal_soup_wnt_l_eer_percent": 40.3585813940,
    "utterance_only_old_map_wnt_l_eer_percent": 40.5973,
    "rows": rows,
}
(root / "checkpoint_wnt_l_screen.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$OUT_ROOT/checkpoint_wnt_l_screen.json" \
  "$OUT_ROOT"/step_*/checkpoint.sha256 \
  "$OUT_ROOT"/step_*/speaker_sampling_wnt_l_comparison.json \
  "$OUT_ROOT"/step_*/wnt/summary.json
echo "CHECKPOINT_WNT_L_SCREEN_COMPLETE out=$OUT_ROOT"
