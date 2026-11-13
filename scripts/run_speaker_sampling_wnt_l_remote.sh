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
RUN_ROOT="${N019_SPKSAMPLE_RUN_ROOT:?Set N019_SPKSAMPLE_RUN_ROOT}"
SUFFIX="${N019_SPKSAMPLE_SUFFIX:-_n019_spksamplediag_20261111}"

VOCODER="${N019_SPKSAMPLE_VOCODER:-/public/home/a094f4d7/voice_projects/tmp/n019_model_soup_round2_candidates_20261110/generator_avg_soup2_quad_w40_30_20_10.pt}"
VOCODER_SHA="${N019_SPKSAMPLE_VOCODER_SHA:-ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6}"
DURATION_MODEL="${N019_SPKSAMPLE_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_pred_paperfix/best.pt}"
TARGET_MAP="${N019_SPKSAMPLE_TARGET_MAP:-$N019_OFFICIAL_RUNS/target_sampling_diag_20261111/libri_test_target_map_speaker_available_seed20261102.jsonl}"
SPEAKER_EMBEDDINGS="${N019_SPKSAMPLE_SPEAKER_EMBEDDINGS:-/public/home/a094f4d7/voice_projects/data/n019_official/processed/embeddings/target_speaker_mean32_all1158_shrink01_20261110.npz}"
SPEAKER_EMBEDDINGS_SHA="${N019_SPKSAMPLE_SPEAKER_EMBEDDINGS_SHA:-28ffbaec9516cd8f5abbc752b40315b9fe958f7d37dc6b6f4a58bcd28c2540a7}"

for required in \
  "$VOCODER" \
  "$DURATION_MODEL" \
  "$TARGET_MAP" \
  "$SPEAKER_EMBEDDINGS" \
  "$VPC_ROOT/libri_test/wav.scp" \
  "$VPC_ROOT/libri_test_enrolls/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/trials" \
  "$VPC_ROOT/libri_test_trials_m/trials"; do
  test -f "$required" || {
    echo "Missing speaker-sampling input: $required" >&2
    exit 1
  }
done
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "$VOCODER_SHA"
test "$(sha256sum "$SPEAKER_EMBEDDINGS" | awk '{print $1}')" = \
  "$SPEAKER_EMBEDDINGS_SHA"

mkdir -p "$RUN_ROOT/embeddings"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "user=$(id -un)"
  echo "date=$(date -Is)"
  echo "run_root=$RUN_ROOT"
  echo "suffix=$SUFFIX"
  echo "vocoder=$VOCODER"
  echo "vocoder_sha256=$VOCODER_SHA"
  echo "target_map=$TARGET_MAP"
  echo "speaker_embeddings=$SPEAKER_EMBEDDINGS"
} | tee "$RUN_ROOT/launch.txt"

python - "$TARGET_MAP" "$SPEAKER_EMBEDDINGS" \
  "$RUN_ROOT/embeddings/speaker_embeddings_subset.npz" \
  "$RUN_ROOT/embeddings/speaker_embeddings_subset.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

target_map_path, embeddings_path, output_path, metadata_path = map(
    Path, sys.argv[1:]
)
required = {
    str(json.loads(line)["target_speaker"])
    for line in target_map_path.read_text(encoding="utf-8").splitlines()
    if line.strip()
}
archive = np.load(embeddings_path, allow_pickle=False)
try:
    missing = required - set(archive.files)
    if missing:
        raise SystemExit(f"Missing speaker embeddings: {sorted(missing)[:10]}")
    output = {key: archive[key].astype(np.float32) for key in sorted(required)}
finally:
    archive.close()
np.savez_compressed(output_path, **output)
metadata = {
    "target_map": str(target_map_path.resolve()),
    "speaker_embeddings": str(embeddings_path.resolve()),
    "keys": len(output),
    "dimension": 250,
    "out": str(output_path.resolve()),
    "out_sha256": hashlib.sha256(output_path.read_bytes()).hexdigest(),
}
metadata_path.write_text(
    json.dumps(metadata, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(metadata, indent=2, sort_keys=True))
PY

ANON="$RUN_ROOT/anonymised"
VERIFY="$ROOT/audit/verify_speaker_sampling_${SLURM_JOB_ID:-manual}.json"
if [[ -f "$ANON/anon.jsonl" ]] &&
   [[ "$(wc -l < "$ANON/anon.jsonl")" == "1934" ]] &&
   [[ "$(find "$ANON" -maxdepth 1 -type f -name '*.wav' | wc -l)" == "1934" ]]; then
  echo "REUSE_COMPLETE_ANON rows=1934"
  python -m n019.export_vpc_anon \
    --vpc-data-dir "$VPC_ROOT" \
    --anon-manifest "$ANON/anon.jsonl" \
    --suffix "$SUFFIX" \
    --dataset-name libri_test \
    --dataset-name libri_test_enrolls \
    --dataset-name libri_test_trials_f \
    --dataset-name libri_test_trials_m \
    --overwrite-missing
  owner="$(stat -c '%u:%g' "$DATA")"
  python "$ROOT/scripts/verify_anonymized_outputs.py" \
    --source-manifest "$DATA/manifests/libri_test.jsonl" \
    --out-dir "$ANON" \
    --vpc-suffix-dir "$VPC_ROOT/libri_test$SUFFIX" \
    --duration-mode pred \
    --vocoder-type nt \
    --expected-records 1934 \
    --expected-uid "${owner%%:*}" \
    --expected-gid "${owner##*:}" \
    --out "$VERIFY"
  chown "$owner" "$VERIFY"
else
  N019_LIBRI_TEST_TARGET_EMBEDDINGS="$RUN_ROOT/embeddings/speaker_embeddings_subset.npz" \
  N019_LIBRI_TEST_TARGET_EMBEDDING_KEY=target_speaker \
  N019_LIBRI_TEST_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1 \
  N019_LIBRI_TEST_TARGET_MAP="$TARGET_MAP" \
  N019_LIBRI_TEST_DURATION_MODEL="$DURATION_MODEL" \
  N019_LIBRI_TEST_VOCODER="$VOCODER" \
  N019_LIBRI_TEST_EXPECTED_VOCODER_SHA="$VOCODER_SHA" \
  N019_LIBRI_TEST_ANON_OUT="$ANON" \
  N019_LIBRI_TEST_SUFFIX="$SUFFIX" \
  N019_LIBRI_TEST_VERIFY="$VERIFY" \
    bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"
fi

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
embedding_metadata_path = root / "embeddings" / "speaker_embeddings_subset.json"
summary = json.loads(summary_path.read_text(encoding="utf-8"))
metadata = json.loads(embedding_metadata_path.read_text(encoding="utf-8"))
result = {
    "paper_wnt_l_eer_percent": 42.3,
    "utterance_sampled_mean32_wnt_l_eer_percent": 39.7293478251,
    "speaker_sampled_mean32_wnt_l": summary["attacks"]["L"],
    "target_speaker_embeddings": metadata["keys"],
    "embedding_sha256": metadata["out_sha256"],
    "summary_sha256": hashlib.sha256(summary_path.read_bytes()).hexdigest(),
}
(root / "speaker_sampling_wnt_l_comparison.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$RUN_ROOT/speaker_sampling_wnt_l_comparison.json" \
  "$RUN_ROOT/embeddings/speaker_embeddings_subset.npz" \
  "$RUN_ROOT/wnt/summary.json"
echo "SPEAKER_SAMPLING_WNT_L_COMPLETE root=$RUN_ROOT"
