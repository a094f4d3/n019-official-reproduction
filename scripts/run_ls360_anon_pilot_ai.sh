#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

ROWS="${N019_ANON_PILOT_ROWS:-1024}"
DURATION_MODE="${N019_ANON_PILOT_DURATION_MODE:-pred}"
DATA="$N019_OFFICIAL_DATA"
SOURCE="$DATA/processed/manifests/librispeech_train_clean_360_pilot${ROWS}.jsonl"
TARGET_MAP="$DATA/processed/targets/librispeech_train_clean_360_target_map_utterance_pilot${ROWS}.jsonl"
UNITS="$DATA/processed/units/librispeech_train_clean_360/unit_records.jsonl"
TARGET_EMBEDDINGS="$DATA/processed/embeddings/librispeech_train_clean_360_target_nt_utterance/nt_utterance_embeddings.npz"
VOCODER="$N019_OFFICIAL_RUNS/vocoder_nt_main/best.pt"
OUT="${N019_ANON_PILOT_OUT:-$N019_OFFICIAL_RUNS/ls360_anon_pilot_${DURATION_MODE}_nt_${ROWS}_$(date +%Y%m%d_%H%M%S)}"

DURATION_ARGS=()
case "$DURATION_MODE" in
  orig) ;;
  pred)
    DURATION_ARGS=(--duration-model "$N019_OFFICIAL_RUNS/duration_pred_main/best.pt")
    ;;
  nt)
    DURATION_ARGS=(
      --duration-model "$N019_OFFICIAL_RUNS/duration_nt_main/best.pt"
      --duration-embeddings "$TARGET_EMBEDDINGS"
    )
    ;;
  *)
    echo "N019_ANON_PILOT_DURATION_MODE must be orig, pred, or nt" >&2
    exit 1
    ;;
esac

for required in "$SOURCE" "$TARGET_MAP" "$UNITS" "$TARGET_EMBEDDINGS" "$VOCODER"; do
  test -f "$required" || {
    echo "Missing pilot input: $required" >&2
    exit 1
  }
done
test ! -e "$OUT" || {
  echo "Pilot output already exists: $OUT" >&2
  exit 1
}

mkdir -p "$OUT"
START_EPOCH=$(date +%s)
START_ISO=$(date -Is)
{
  echo "account_root=ok user=$(id -un) host=$(hostname)"
  echo "rows=$ROWS duration_mode=$DURATION_MODE"
  echo "source=$SOURCE"
  echo "target_map=$TARGET_MAP"
  echo "units=$UNITS"
  echo "target_embeddings=$TARGET_EMBEDDINGS"
  echo "vocoder=$VOCODER"
  echo "out=$OUT"
} | tee "$OUT/launch.txt"

if command -v /usr/bin/time >/dev/null 2>&1; then
  /usr/bin/time -v python -u -m n019.anonymize \
    --source-manifest "$SOURCE" \
    --unit-records "$UNITS" \
    --target-map "$TARGET_MAP" \
    --duration-mode "$DURATION_MODE" \
    "${DURATION_ARGS[@]}" \
    --vocoder "$VOCODER" \
    --vocoder-type nt \
    --vocoder-embeddings "$TARGET_EMBEDDINGS" \
    --out-dir "$OUT" \
    --device cuda 2>&1 | tee "$OUT/stdout.log"
else
  python -u -m n019.anonymize \
    --source-manifest "$SOURCE" \
    --unit-records "$UNITS" \
    --target-map "$TARGET_MAP" \
    --duration-mode "$DURATION_MODE" \
    "${DURATION_ARGS[@]}" \
    --vocoder "$VOCODER" \
    --vocoder-type nt \
    --vocoder-embeddings "$TARGET_EMBEDDINGS" \
    --out-dir "$OUT" \
    --device cuda 2>&1 | tee "$OUT/stdout.log"
fi

END_EPOCH=$(date +%s)
ELAPSED=$((END_EPOCH - START_EPOCH))
WAV_COUNT=$(find "$OUT" -maxdepth 1 -type f -name '*.wav' | wc -l)
python - "$OUT" "$ROWS" "$DURATION_MODE" "$START_ISO" "$(date -Is)" "$ELAPSED" "$WAV_COUNT" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
rows = int(sys.argv[2])
elapsed = int(sys.argv[6])
payload = {
    "rows": rows,
    "duration_mode": sys.argv[3],
    "start": sys.argv[4],
    "end": sys.argv[5],
    "elapsed_seconds": elapsed,
    "utterances_per_second": rows / elapsed if elapsed > 0 else None,
    "wav_files": int(sys.argv[7]),
}
(out / "pilot_metrics.json").write_text(
    json.dumps(payload, indent=2) + "\n",
    encoding="utf-8",
)
print(json.dumps(payload, indent=2))
PY

OWNER=$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")
chown -R "$OWNER" "$OUT"
echo "LS360_ANON_PILOT_COMPLETE out=$OUT elapsed_seconds=$ELAPSED"
