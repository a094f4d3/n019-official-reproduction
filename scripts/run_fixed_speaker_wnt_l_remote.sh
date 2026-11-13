#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

DATA="$N019_OFFICIAL_DATA/processed"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
RUN_ROOT="${N019_FIXED_RUN_ROOT:?Set N019_FIXED_RUN_ROOT}"
SUFFIX="${N019_FIXED_SUFFIX:-_n019_fixedspkdiag_20261111}"

VOCODER="${N019_FIXED_VOCODER:-/public/home/a094f4d7/voice_projects/tmp/n019_model_soup_round2_candidates_20261110/generator_avg_soup2_quad_w40_30_20_10.pt}"
VOCODER_SHA="${N019_FIXED_VOCODER_SHA:-ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6}"
DURATION_MODEL="${N019_FIXED_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_pred_paperfix/best.pt}"
SOURCE_MAP="${N019_FIXED_SOURCE_MAP:-$DATA/targets/libri_test_target_map_paperfix.jsonl}"
SPEAKER_EMBEDDINGS="${N019_FIXED_SPEAKER_EMBEDDINGS:-/public/home/a094f4d6/voice_projects/tmp/n019_mean32_shrink_ab_20261110/nt_speaker_embeddings_shrink01.npz}"
SPEAKER_EMBEDDINGS_SHA="${N019_FIXED_SPEAKER_EMBEDDINGS_SHA:-f51ea75edaa75c629d3634a8c60ff6a6b97f66197f8de34a419e18e0054efad5}"

for required in \
  "$VOCODER" \
  "$DURATION_MODEL" \
  "$SOURCE_MAP" \
  "$SPEAKER_EMBEDDINGS" \
  "$VPC_ROOT/libri_test/wav.scp" \
  "$VPC_ROOT/libri_test_enrolls/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/trials" \
  "$VPC_ROOT/libri_test_trials_m/trials"; do
  test -f "$required" || {
    echo "Missing fixed-speaker input: $required" >&2
    exit 1
  }
done
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "$VOCODER_SHA"
test "$(sha256sum "$SPEAKER_EMBEDDINGS" | awk '{print $1}')" = \
  "$SPEAKER_EMBEDDINGS_SHA"

mkdir -p "$RUN_ROOT/map" "$RUN_ROOT/embeddings"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "user=$(id -un)"
  echo "date=$(date -Is)"
  echo "run_root=$RUN_ROOT"
  echo "suffix=$SUFFIX"
  echo "vocoder=$VOCODER"
  echo "vocoder_sha256=$VOCODER_SHA"
  echo "source_map=$SOURCE_MAP"
  echo "speaker_embeddings=$SPEAKER_EMBEDDINGS"
} | tee "$RUN_ROOT/launch.txt"

python "$ROOT/scripts/make_fixed_speaker_target_map.py" \
  --target-map "$SOURCE_MAP" \
  --out "$RUN_ROOT/map/target_map_fixed_speaker.jsonl" \
  --metadata "$RUN_ROOT/map/target_map_fixed_speaker.json"

python - "$RUN_ROOT/map/target_map_fixed_speaker.jsonl" \
  "$SPEAKER_EMBEDDINGS" "$RUN_ROOT/embeddings/speaker_embeddings_fixed.npz" <<'PY'
import json
import sys
from pathlib import Path

import numpy as np

target_map_path, embeddings_path, output_path = map(Path, sys.argv[1:])
required = {
    str(json.loads(line)["target_speaker"])
    for line in target_map_path.read_text(encoding="utf-8").splitlines()
    if line.strip()
}
archive = np.load(embeddings_path, allow_pickle=False)
try:
    missing = required - set(archive.files)
    if missing:
        raise SystemExit(f"Missing fixed-speaker embeddings: {sorted(missing)}")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(
        output_path,
        **{key: archive[key].astype(np.float32) for key in sorted(required)},
    )
finally:
    archive.close()
print(f"WROTE_FIXED_SPEAKER_EMBEDDINGS keys={len(required)}")
PY

N019_LIBRI_TEST_TARGET_EMBEDDINGS="$RUN_ROOT/embeddings/speaker_embeddings_fixed.npz" \
N019_LIBRI_TEST_TARGET_EMBEDDING_KEY=target_speaker \
N019_LIBRI_TEST_TARGET_EMBEDDING_MODE=fixed_speaker_mean32_shrink01 \
N019_LIBRI_TEST_TARGET_MAP="$RUN_ROOT/map/target_map_fixed_speaker.jsonl" \
N019_LIBRI_TEST_DURATION_MODEL="$DURATION_MODEL" \
N019_LIBRI_TEST_VOCODER="$VOCODER" \
N019_LIBRI_TEST_EXPECTED_VOCODER_SHA="$VOCODER_SHA" \
N019_LIBRI_TEST_ANON_OUT="$RUN_ROOT/anonymised" \
N019_LIBRI_TEST_SUFFIX="$SUFFIX" \
N019_LIBRI_TEST_VERIFY="$ROOT/audit/verify_fixed_speaker_${SLURM_JOB_ID:-manual}.json" \
  bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

N019_DATA_SUFFIX="$SUFFIX" \
N019_VPC_DATA="$VPC_ROOT" \
N019_WNT_BASE_VPC_DATA="$VPC_ROOT" \
N019_WNT_ATTACKS=L \
N019_WNT_OUT="$RUN_ROOT/wnt" \
  bash "$ROOT/scripts/evaluate_wnt_remote.sh"

python - "$RUN_ROOT" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
summary_path = root / "wnt" / "summary.json"
map_metadata_path = root / "map" / "target_map_fixed_speaker.json"
summary = json.loads(summary_path.read_text(encoding="utf-8"))
map_metadata = json.loads(map_metadata_path.read_text(encoding="utf-8"))
result = {
    "paper_wnt_l_eer_percent": 42.3,
    "random_target_baseline_wnt_l_eer_percent": 39.7293478251,
    "fixed_target_speaker": summary["attacks"]["L"],
    "source_speakers": map_metadata["source_speakers"],
    "target_speakers": map_metadata["target_speakers"],
    "target_map_sha256": map_metadata["out_sha256"],
    "summary_sha256": hashlib.sha256(summary_path.read_bytes()).hexdigest(),
}
(root / "fixed_speaker_wnt_l_comparison.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$RUN_ROOT/fixed_speaker_wnt_l_comparison.json" \
  "$RUN_ROOT/map/target_map_fixed_speaker.jsonl" \
  "$RUN_ROOT/embeddings/speaker_embeddings_fixed.npz" \
  "$RUN_ROOT/wnt/summary.json"
echo "FIXED_SPEAKER_WNT_L_COMPLETE root=$RUN_ROOT"
