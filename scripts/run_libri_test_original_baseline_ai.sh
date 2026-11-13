#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

DATA="$N019_OFFICIAL_DATA/processed"
SOURCE="$DATA/manifests/libri_test.jsonl"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
SUFFIX="_n019_orig"
RUN_NAME="baseline_orig_vpc"

test "$(wc -l < "$SOURCE")" = 1934
test "$(sha256sum "$SOURCE" | awk '{print $1}')" = \
  d97cafa5790e69c41c14bda6d130148dc982933c22d2fccbdd421b0723e1c432

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

test "$(wc -l < "$VPC_ROOT/libri_test/wav.scp")" = 1934
test "$(wc -l < "$VPC_ROOT/libri_test_enrolls/wav.scp")" = 438
test "$(wc -l < "$VPC_ROOT/libri_test_trials_f/wav.scp")" = 734
test "$(wc -l < "$VPC_ROOT/libri_test_trials_f/trials")" = 11744
test "$(wc -l < "$VPC_ROOT/libri_test_trials_m/wav.scp")" = 762
test "$(wc -l < "$VPC_ROOT/libri_test_trials_m/trials")" = 9906

for dataset in \
  libri_test \
  libri_test_enrolls \
  libri_test_trials_f \
  libri_test_trials_m; do
  ln -sfn "$VPC_ROOT/$dataset" "$VPC_ROOT/$dataset$SUFFIX"
done

N019_DATA_SUFFIX="$SUFFIX" \
N019_RUN_NAME="$RUN_NAME" \
  bash "$ROOT/scripts/evaluate_evpc_pre_remote.sh"

OUT="$N019_OFFICIAL_RUNS/eval/$RUN_NAME/evpc"
test -s "$OUT/evpc_metrics.json"
owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
chown -R "$owner" "$N019_OFFICIAL_RUNS/eval/$RUN_NAME"
chown -h "$owner" \
  "$VPC_ROOT/libri_test$SUFFIX" \
  "$VPC_ROOT/libri_test_enrolls$SUFFIX" \
  "$VPC_ROOT/libri_test_trials_f$SUFFIX" \
  "$VPC_ROOT/libri_test_trials_m$SUFFIX"

sha256sum \
  "$SOURCE" \
  "$VPC_ROOT/libri_test/wav.scp" \
  "$OUT/evpc_metrics.json" \
  "$OUT/exp/results_summary/eval_orig$SUFFIX/results_orig.txt"
echo "LIBRI_TEST_ORIGINAL_BASELINE_COMPLETE out=$OUT suffix=$SUFFIX"
