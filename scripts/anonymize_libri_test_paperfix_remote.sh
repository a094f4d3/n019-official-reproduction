#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

DATA="$N019_OFFICIAL_DATA/processed"
SOURCE="${N019_LIBRI_TEST_SOURCE:-$DATA/manifests/libri_test.jsonl}"
UNITS="${N019_LIBRI_TEST_UNITS:-$DATA/units/libri_test_paperfix/unit_records.jsonl}"
TARGET_MAP="${N019_LIBRI_TEST_TARGET_MAP:-$DATA/targets/libri_test_target_map_paperfix.jsonl}"
TARGET_EMBEDDINGS="${N019_LIBRI_TEST_TARGET_EMBEDDINGS:-$DATA/embeddings/libri_test_target_nt_utterance_paperfix/nt_utterance_embeddings.npz}"
TARGET_EMBEDDING_KEY="${N019_LIBRI_TEST_TARGET_EMBEDDING_KEY:-target_id}"
TARGET_EMBEDDING_MODE="${N019_LIBRI_TEST_TARGET_EMBEDDING_MODE:-utterance}"
DURATION_MODE="${N019_LIBRI_TEST_DURATION_MODE:-pred}"
DURATION_EMBEDDING_KEY="${N019_LIBRI_TEST_DURATION_EMBEDDING_KEY:-target_id}"
VOCODER="${N019_LIBRI_TEST_VOCODER:-$N019_OFFICIAL_RUNS/vocoder_nt_paperfix/best.pt}"
OUT="${N019_LIBRI_TEST_ANON_OUT:-$N019_OFFICIAL_DATA/anonymised/libri_test/DU-pred-nt-paperfix}"
VPC_ROOT="${N019_LIBRI_TEST_VPC_DATA:-${N019_VPC_DATA:-$N019_OFFICIAL_DATA/vpc/data}}"
SUFFIX="${N019_LIBRI_TEST_SUFFIX:-_n019_paperfix}"
VERIFY="${N019_LIBRI_TEST_VERIFY:-$ROOT/audit/verify_libri_test_du_pred_nt_paperfix.json}"

EXPECTED_SOURCE_SHA="${N019_LIBRI_TEST_EXPECTED_SOURCE_SHA:-d97cafa5790e69c41c14bda6d130148dc982933c22d2fccbdd421b0723e1c432}"
EXPECTED_DURATION_SHA="${N019_LIBRI_TEST_EXPECTED_DURATION_SHA:-8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c}"
EXPECTED_VOCODER_SHA="${N019_LIBRI_TEST_EXPECTED_VOCODER_SHA:-f1735e757ecfc4bfb6a230ae26219058e6aed8bef18656bb2b694cc89ed070d9}"

DURATION_MODEL_ARGS=()
DURATION_EMBEDDING_ARGS=()
DURATION_MODEL=""
DURATION_EMBEDDINGS=""
case "$DURATION_MODE" in
  orig)
    DURATION_MODEL="${N019_LIBRI_TEST_DURATION_MODEL:-}"
    ;;
  pred)
    DURATION_MODEL="${N019_LIBRI_TEST_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_pred_paperfix/best.pt}"
    DURATION_MODEL_ARGS=(--duration-model "$DURATION_MODEL")
    DURATION_EMBEDDINGS=""
    ;;
  nt)
    DURATION_MODEL="${N019_LIBRI_TEST_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_nt_main/best.pt}"
    DURATION_MODEL_ARGS=(--duration-model "$DURATION_MODEL")
    DURATION_EMBEDDINGS="${N019_LIBRI_TEST_DURATION_EMBEDDINGS:?Set N019_LIBRI_TEST_DURATION_EMBEDDINGS for duration mode nt}"
    DURATION_EMBEDDING_ARGS=(--duration-embeddings "$DURATION_EMBEDDINGS")
    ;;
  ecapa)
    DURATION_MODEL="${N019_LIBRI_TEST_DURATION_MODEL:-$N019_OFFICIAL_RUNS/duration_ecapa_main/best.pt}"
    DURATION_MODEL_ARGS=(--duration-model "$DURATION_MODEL")
    DURATION_EMBEDDINGS="${N019_LIBRI_TEST_DURATION_EMBEDDINGS:?Set N019_LIBRI_TEST_DURATION_EMBEDDINGS for duration mode ecapa}"
    DURATION_EMBEDDING_ARGS=(--duration-embeddings "$DURATION_EMBEDDINGS")
    ;;
  *)
    echo "N019_LIBRI_TEST_DURATION_MODE must be orig, pred, nt, or ecapa" >&2
    exit 1
    ;;
esac

case "$TARGET_EMBEDDING_KEY" in
  target_id)
    case "$TARGET_EMBEDDING_MODE" in
      utterance|utterance_mix_w*) ;;
      *)
        echo "Unsupported target-utterance embedding mode: $TARGET_EMBEDDING_MODE" >&2
        exit 1
        ;;
    esac
    ;;
  target_speaker)
    case "$TARGET_EMBEDDING_MODE" in
      speaker_mean_l2|speaker_mean_l2_shrink0.1|source_speaker_mean_l2)
        ;;
      *)
        echo "Unsupported target-speaker embedding mode: $TARGET_EMBEDDING_MODE" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Invalid target embedding key: $TARGET_EMBEDDING_KEY" >&2
    exit 1
    ;;
esac

test "$(sha256sum "$SOURCE" | awk '{print $1}')" = "$EXPECTED_SOURCE_SHA"
if [[ ! -s "$VPC_ROOT/libri_test/wav.scp" ]]; then
  python - "$SOURCE" "$VPC_ROOT/libri_test/wav.scp" <<'PY'
import json
import sys
from pathlib import Path

source_path, output_path = map(Path, sys.argv[1:])
rows = [json.loads(line) for line in source_path.open(encoding="utf-8")]
if len(rows) != 1934:
    raise SystemExit("libri_test source must contain 1934 rows")
lines = []
for row in rows:
    identifier = str(row["id"])
    audio = Path(str(row["audio"])).resolve()
    if not audio.is_file():
        raise FileNotFoundError(audio)
    lines.append(f"{identifier} {audio}")
output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"WROTE_LIBRI_TEST_WAV_SCP rows={len(lines)}")
PY
fi

required_files=(
  "$SOURCE"
  "$UNITS"
  "$TARGET_MAP"
  "$TARGET_EMBEDDINGS"
  "$VOCODER"
  "$VPC_ROOT/libri_test/wav.scp"
  "$VPC_ROOT/libri_test_enrolls/wav.scp"
  "$VPC_ROOT/libri_test_trials_f/wav.scp"
  "$VPC_ROOT/libri_test_trials_f/trials"
  "$VPC_ROOT/libri_test_trials_m/wav.scp"
  "$VPC_ROOT/libri_test_trials_m/trials"
)
if [[ "$DURATION_MODE" != "orig" ]]; then
  required_files+=("$DURATION_MODEL")
fi
if [[ ${#DURATION_EMBEDDING_ARGS[@]} -gt 0 ]]; then
  required_files+=("$DURATION_EMBEDDINGS")
fi
for required in "${required_files[@]}"; do
  test -f "$required" || {
    echo "Missing libri_test anonymisation input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$SOURCE")" = 1934
test "$(wc -l < "$UNITS")" = 1934
test "$(wc -l < "$TARGET_MAP")" = 1934
test "$(wc -l < "$VPC_ROOT/libri_test/wav.scp")" = 1934
if [[ "$DURATION_MODE" != "orig" ]]; then
  test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = "$EXPECTED_DURATION_SHA"
fi
test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "$EXPECTED_VOCODER_SHA"

python - "$SOURCE" "$UNITS" "$TARGET_MAP" "$TARGET_EMBEDDINGS" \
  "$TARGET_EMBEDDING_KEY" "$TARGET_EMBEDDING_MODE" <<'PY'
import json
import sys
from pathlib import Path

import numpy as np

args = sys.argv[1:]
source_path, units_path, map_path, npz_path = map(Path, args[:4])
embedding_key, embedding_mode = args[4:]
sources = [json.loads(line) for line in source_path.open(encoding="utf-8")]
units = [json.loads(line) for line in units_path.open(encoding="utf-8")]
mappings = [json.loads(line) for line in map_path.open(encoding="utf-8")]
source_ids = [str(row["id"]) for row in sources]
unit_ids = [str(row["id"]) for row in units]
mapping_source_ids = [str(row["source_id"]) for row in mappings]
target_ids = {str(row["target_id"]) for row in mappings}
target_speakers = {str(row["target_speaker"]) for row in mappings}
if len(source_ids) != 1934 or len(set(source_ids)) != 1934:
    raise SystemExit("libri_test source must contain 1934 unique IDs")
if len({str(row["speaker"]) for row in sources}) != 40:
    raise SystemExit("libri_test source must contain 40 speakers")
if set(unit_ids) != set(source_ids):
    raise SystemExit("libri_test unit/source ID mismatch")
if len(mapping_source_ids) != len(set(mapping_source_ids)):
    raise SystemExit("duplicate target-map source IDs")
if set(mapping_source_ids) != set(source_ids):
    raise SystemExit("libri_test target-map/source ID mismatch")
archive = np.load(npz_path, allow_pickle=False)
try:
    expected_keys = (
        target_ids if embedding_key == "target_id" else target_speakers
    )
    if set(archive.files) != expected_keys:
        raise SystemExit(
            "target embedding/target-map key mismatch for "
            f"{embedding_key} with {embedding_mode}"
        )
    for key in sorted(expected_keys):
        value = archive[key]
        if value.shape != (250,):
            raise SystemExit(f"bad embedding shape for {key}: {value.shape}")
        if not np.isfinite(value).all():
            raise SystemExit(f"non-finite embedding for {key}")
        norm = float(np.linalg.norm(value))
        if abs(norm - 1.0) > 1e-4:
            raise SystemExit(f"bad embedding norm for {key}: {norm}")
finally:
    archive.close()
print(
    f"INPUTS_OK source=1934 units=1934 speakers=40 "
    f"unique_targets={len(target_ids)} embedding_keys={len(expected_keys)} "
    f"dim=250 key={embedding_key} mode={embedding_mode}"
)
PY

if [[ ${#DURATION_EMBEDDING_ARGS[@]} -gt 0 ]]; then
  DURATION_EMBEDDING_DIM=250
  if [[ "$DURATION_MODE" == "ecapa" ]]; then
    DURATION_EMBEDDING_DIM=192
  fi
  python - "$TARGET_MAP" "$DURATION_EMBEDDINGS" \
    "$DURATION_EMBEDDING_KEY" "$TARGET_EMBEDDING_MODE" \
    "$DURATION_EMBEDDING_DIM" <<'PY'
import json
import sys

import numpy as np

map_path, embeddings_path, key_name, embedding_mode, dimension = sys.argv[1:]
dimension = int(dimension)
required = set()
with open(map_path, encoding="utf-8") as handle:
    for line in handle:
        if line.strip():
            required.add(str(json.loads(line)[key_name]))
archive = np.load(embeddings_path, allow_pickle=False)
try:
    missing = sorted(required - set(archive.files))
    if missing:
        raise SystemExit(
            f"Missing {len(missing)} duration embedding keys; first={missing[:10]}"
        )
    for key in sorted(required):
        value = archive[key]
        if value.shape != (dimension,):
            raise SystemExit(f"bad duration embedding shape for {key}: {value.shape}")
        if not np.isfinite(value).all():
            raise SystemExit(f"non-finite duration embedding for {key}")
finally:
    archive.close()
print(
    f"DURATION_INPUTS_OK keys={len(required)} key={key_name} "
    f"mode={embedding_mode} dim={dimension}"
)
PY
fi

mkdir -p "$OUT"
RESUME_FLAG=()
if [[ -f "$OUT/anon.partial.jsonl" ]]; then
  RESUME_FLAG=(--resume)
fi

{
  echo "user=$(id -un) uid=$(id -u) gid=$(id -g) host=$(hostname) date=$(date -Is)"
  echo "job=${SLURM_JOB_ID:-manual} scope=libri_test_paperfix"
  echo "source=$SOURCE"
  echo "units=$UNITS"
  echo "target_map=$TARGET_MAP"
  echo "target_embeddings=$TARGET_EMBEDDINGS"
  echo "target_embedding_key=$TARGET_EMBEDDING_KEY"
  echo "target_embedding_mode=$TARGET_EMBEDDING_MODE"
  echo "duration_mode=$DURATION_MODE"
  echo "duration_model=${DURATION_MODEL:-none}"
  echo "duration_embeddings=${DURATION_EMBEDDINGS:-none}"
  echo "duration_embedding_key=$DURATION_EMBEDDING_KEY"
  echo "vocoder=$VOCODER"
  echo "out=$OUT"
  echo "resume=${#RESUME_FLAG[@]}"
} | tee "$OUT/launch.txt"

python -u -m n019.anonymize \
  --source-manifest "$SOURCE" \
  --unit-records "$UNITS" \
  --target-map "$TARGET_MAP" \
  --duration-mode "$DURATION_MODE" \
  "${DURATION_MODEL_ARGS[@]}" \
  "${DURATION_EMBEDDING_ARGS[@]}" \
  --duration-embedding-key "$DURATION_EMBEDDING_KEY" \
  --vocoder "$VOCODER" \
  --vocoder-type nt \
  --vocoder-embeddings "$TARGET_EMBEDDINGS" \
  --target-embedding-key "$TARGET_EMBEDDING_KEY" \
  --target-embedding-mode "$TARGET_EMBEDDING_MODE" \
  --speaker-embedding-scale "${N019_SPEAKER_EMBEDDING_SCALE:-1.0}" \
  --duration-extrapolation "${N019_DURATION_EXTRAPOLATION:-0.0}" \
  ${N019_DURATION_PRESERVE_TOTAL:+--duration-preserve-total} \
  --duration-soft-cap-frames "${N019_DURATION_SOFT_CAP_FRAMES:-0.0}" \
  --out-dir "$OUT" \
  --device cuda \
  "${RESUME_FLAG[@]}"

python -m n019.export_vpc_anon \
  --vpc-data-dir "$VPC_ROOT" \
  --anon-manifest "$OUT/anon.jsonl" \
  --suffix "$SUFFIX" \
  --dataset-name libri_test \
  --dataset-name libri_test_enrolls \
  --dataset-name libri_test_trials_f \
  --dataset-name libri_test_trials_m \
  --overwrite-missing

test "$(wc -l < "$VPC_ROOT/libri_test$SUFFIX/wav.scp")" = 1934
test "$(wc -l < "$VPC_ROOT/libri_test_enrolls$SUFFIX/wav.scp")" = 438
test "$(wc -l < "$VPC_ROOT/libri_test_trials_f$SUFFIX/wav.scp")" = 734
test "$(wc -l < "$VPC_ROOT/libri_test_trials_f$SUFFIX/trials")" = 11744
test "$(wc -l < "$VPC_ROOT/libri_test_trials_m$SUFFIX/wav.scp")" = 762
test "$(wc -l < "$VPC_ROOT/libri_test_trials_m$SUFFIX/trials")" = 9906

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
uid="${owner%%:*}"
gid="${owner##*:}"
chown -R "$owner" \
  "$OUT" \
  "$VPC_ROOT/libri_test$SUFFIX" \
  "$VPC_ROOT/libri_test_enrolls$SUFFIX" \
  "$VPC_ROOT/libri_test_trials_f$SUFFIX" \
  "$VPC_ROOT/libri_test_trials_m$SUFFIX"

python "$ROOT/scripts/verify_anonymized_outputs.py" \
  --source-manifest "$SOURCE" \
  --out-dir "$OUT" \
  --vpc-suffix-dir "$VPC_ROOT/libri_test$SUFFIX" \
  --duration-mode "$DURATION_MODE" \
  --vocoder-type nt \
  --expected-records 1934 \
  --expected-uid "$uid" \
  --expected-gid "$gid" \
  --out "$VERIFY"

chown "$owner" "$VERIFY"
sha256sum \
  "$SOURCE" \
  "$UNITS" \
  "$TARGET_MAP" \
  "$TARGET_EMBEDDINGS" \
  ${DURATION_MODEL:+"$DURATION_MODEL"} \
  ${DURATION_EMBEDDINGS:+"$DURATION_EMBEDDINGS"} \
  "$VOCODER" \
  "$OUT/anon.jsonl" \
  "$OUT/run_meta.json" \
  "$VPC_ROOT/libri_test$SUFFIX/wav.scp" \
  "$VERIFY"
echo "LIBRI_TEST_DU_PRED_NT_PAPERFIX_COMPLETE out=$OUT suffix=$SUFFIX"
