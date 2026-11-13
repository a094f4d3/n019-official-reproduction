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
RUN_ROOT="${N019_MIX_RUN_ROOT:?Set N019_MIX_RUN_ROOT}"
SUFFIX_ROOT="${N019_MIX_SUFFIX_ROOT:-_n019_mixdiag_20261111}"
WEIGHTS="${N019_MIX_WEIGHTS:-0.25 0.50 0.75}"

VOCODER="${N019_MIX_VOCODER:-/public/home/a094f4d7/voice_projects/tmp/n019_model_soup_round2_candidates_20261110/generator_avg_soup2_quad_w40_30_20_10.pt}"
VOCODER_SHA="${N019_MIX_VOCODER_SHA:-ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6}"
DURATION_MODEL="${N019_MIX_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_pred_paperfix/best.pt}"
TARGET_MAP="${N019_MIX_TARGET_MAP:-$DATA/targets/libri_test_target_map_paperfix.jsonl}"
SOURCE_MANIFEST="${N019_MIX_SOURCE_MANIFEST:-$DATA/manifests/libri_test.jsonl}"
UNIT_RECORDS="${N019_MIX_UNIT_RECORDS:-$DATA/units/libri_test_paperfix/unit_records.jsonl}"
SPEAKER_EMBEDDINGS="${N019_MIX_SPEAKER_EMBEDDINGS:-/public/home/a094f4d6/voice_projects/tmp/n019_mean32_shrink_ab_20261110/nt_speaker_embeddings_shrink01.npz}"
SPEAKER_EMBEDDINGS_SHA="${N019_MIX_SPEAKER_EMBEDDINGS_SHA:-f51ea75edaa75c629d3634a8c60ff6a6b97f66197f8de34a419e18e0054efad5}"
UTTERANCE_EMBEDDINGS="${N019_MIX_UTTERANCE_EMBEDDINGS:-/public/home/a094f4d7/voice_projects/data/n019_official/processed/embeddings/libri_test_target_nt_utterance_paperfix/nt_utterance_embeddings.npz}"
UTTERANCE_EMBEDDINGS_SHA="${N019_MIX_UTTERANCE_EMBEDDINGS_SHA:-0c2a747220bac2a231cbde981a9d5dfca621750348f87f7ce18fab84994a58b7}"

for required in \
  "$VOCODER" \
  "$DURATION_MODEL" \
  "$TARGET_MAP" \
  "$SOURCE_MANIFEST" \
  "$UNIT_RECORDS" \
  "$SPEAKER_EMBEDDINGS" \
  "$UTTERANCE_EMBEDDINGS" \
  "$VPC_ROOT/libri_test/wav.scp" \
  "$VPC_ROOT/libri_test_enrolls/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f/trials" \
  "$VPC_ROOT/libri_test_trials_m/trials"; do
  test -f "$required" || {
    echo "Missing target-mix input: $required" >&2
    exit 1
  }
done
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "$VOCODER_SHA"
if [[ -n "$SPEAKER_EMBEDDINGS_SHA" ]]; then
  test "$(sha256sum "$SPEAKER_EMBEDDINGS" | awk '{print $1}')" = \
    "$SPEAKER_EMBEDDINGS_SHA"
fi
if [[ -n "$UTTERANCE_EMBEDDINGS_SHA" ]]; then
  test "$(sha256sum "$UTTERANCE_EMBEDDINGS" | awk '{print $1}')" = \
    "$UTTERANCE_EMBEDDINGS_SHA"
fi

mkdir -p "$RUN_ROOT/embeddings"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "user=$(id -un)"
  echo "date=$(date -Is)"
  echo "run_root=$RUN_ROOT"
  echo "weights=$WEIGHTS"
  echo "vocoder=$VOCODER"
  echo "vocoder_sha256=$VOCODER_SHA"
  echo "speaker_embeddings=$SPEAKER_EMBEDDINGS"
  echo "utterance_embeddings=$UTTERANCE_EMBEDDINGS"
  echo "target_map=$TARGET_MAP"
  echo "source_manifest=$SOURCE_MANIFEST"
  echo "unit_records=$UNIT_RECORDS"
} | tee "$RUN_ROOT/launch.txt"

for weight in $WEIGHTS; do
  tag="$(python - "$weight" <<'PY'
import sys
print(f"{float(sys.argv[1]):.2f}".replace(".", ""))
PY
)"
  suffix="${SUFFIX_ROOT}_w${tag}"
  embeddings="$RUN_ROOT/embeddings/mix_w${tag}.npz"
  metadata="$RUN_ROOT/embeddings/mix_w${tag}.json"
  anon="$RUN_ROOT/anonymised/w${tag}"
  verify="$ROOT/audit/verify_target_mix_w${tag}_${SLURM_JOB_ID:-manual}.json"
  wnt_out="$RUN_ROOT/wnt/w${tag}"

  python "$ROOT/scripts/mix_target_embeddings.py" \
    --target-map "$TARGET_MAP" \
    --speaker-embeddings "$SPEAKER_EMBEDDINGS" \
    --utterance-embeddings "$UTTERANCE_EMBEDDINGS" \
    --utterance-weight "$weight" \
    --out "$embeddings" \
    --metadata "$metadata"

  N019_LIBRI_TEST_TARGET_EMBEDDINGS="$embeddings" \
  N019_LIBRI_TEST_TARGET_EMBEDDING_KEY=target_id \
  N019_LIBRI_TEST_TARGET_EMBEDDING_MODE="utterance_mix_w${tag}" \
  N019_LIBRI_TEST_SOURCE="$SOURCE_MANIFEST" \
  N019_LIBRI_TEST_UNITS="$UNIT_RECORDS" \
  N019_LIBRI_TEST_TARGET_MAP="$TARGET_MAP" \
  N019_LIBRI_TEST_DURATION_MODEL="$DURATION_MODEL" \
  N019_LIBRI_TEST_VOCODER="$VOCODER" \
  N019_LIBRI_TEST_EXPECTED_VOCODER_SHA="$VOCODER_SHA" \
  N019_LIBRI_TEST_ANON_OUT="$anon" \
  N019_LIBRI_TEST_SUFFIX="$suffix" \
  N019_LIBRI_TEST_VERIFY="$verify" \
    bash "$ROOT/scripts/anonymize_libri_test_paperfix_remote.sh"

  N019_DATA_SUFFIX="$suffix" \
  N019_VPC_DATA="$VPC_ROOT" \
  N019_WNT_BASE_VPC_DATA="$VPC_ROOT" \
  N019_WNT_ATTACKS=L \
  N019_WNT_OUT="$wnt_out" \
    bash "$ROOT/scripts/evaluate_wnt_remote.sh"
done

python - "$RUN_ROOT" "$WEIGHTS" "$SUFFIX_ROOT" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
weights = [float(value) for value in sys.argv[2].split()]
suffix_root = sys.argv[3]
rows = []
for weight in weights:
    tag = f"{weight:.2f}".replace(".", "")
    summary_path = root / "wnt" / f"w{tag}" / "summary.json"
    metadata_path = root / "embeddings" / f"mix_w{tag}.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    rows.append(
        {
            "utterance_weight": weight,
            "suffix": f"{suffix_root}_w{tag}",
            "wnt_l_female_eer_percent": summary["attacks"]["L"][
                "female_eer_percent"
            ],
            "wnt_l_male_eer_percent": summary["attacks"]["L"][
                "male_eer_percent"
            ],
            "wnt_l_mean_eer_percent": summary["attacks"]["L"][
                "mean_eer_percent"
            ],
            "embedding_sha256": metadata["out_sha256"],
            "summary_sha256": hashlib.sha256(
                summary_path.read_bytes()
            ).hexdigest(),
        }
    )
result = {
    "paper_wnt_l_eer_percent": 42.3,
    "baseline_wnt_l_eer_percent": 39.7293478251,
    "utterance_only_wnt_l_eer_percent": 40.5973,
    "rows": rows,
}
(root / "wnt_l_mix_comparison.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum \
  "$RUN_ROOT/wnt_l_mix_comparison.json" \
  "$RUN_ROOT"/embeddings/mix_w*.npz \
  "$RUN_ROOT"/wnt/w*/summary.json
echo "TARGET_MIX_WNT_L_COMPLETE root=$RUN_ROOT"
