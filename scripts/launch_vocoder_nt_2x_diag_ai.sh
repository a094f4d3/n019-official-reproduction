#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

INIT="${N019_2X_INIT_GENERATOR:-$N019_OFFICIAL_RUNS/audit/vocoder_checkpoint_cpu_20261106/checkpoints/paperfix_ext_best_step102000.pt}"
INIT_SHA="62eb5908aae998f50eed1456a8f6a8f606a88c07627c1d92517f0d072c9ff151"
OUT="${N019_2X_OUT:-$N019_OFFICIAL_RUNS/vocoder_nt_2x_diag}"

test -f "$INIT" || {
  echo "Missing 2x diagnostic initializer: $INIT" >&2
  exit 1
}
test "$(sha256sum "$INIT" | awk '{print $1}')" = "$INIT_SHA" || {
  echo "Unexpected initializer SHA256: $INIT" >&2
  exit 1
}
if [[ -e "$OUT/last.pt" && "${N019_2X_ALLOW_RESUME:-0}" != "1" ]]; then
  echo "Refusing to touch existing run without N019_2X_ALLOW_RESUME=1: $OUT" >&2
  exit 1
fi

export N019_NPROC="${N019_2X_NPROC:-2}"
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RUN_NAME=vocoder_nt_2x_diag
export N019_VOCODER_OUT="$OUT"
export N019_VOCODER_STEPS="${N019_2X_STEPS:-20000}"
export N019_VOCODER_MAX_HOURS="${N019_2X_MAX_HOURS:-2.0}"
export N019_VOCODER_CHECKPOINT_INTERVAL="${N019_2X_CHECKPOINT_INTERVAL:-2000}"
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL="${N019_2X_SNAPSHOT_INTERVAL:-2000}"
export N019_VOCODER_KEEP_INTERVAL="${N019_2X_KEEP_INTERVAL:-10000}"
export N019_VOCODER_VALIDATION_INTERVAL="${N019_2X_VALIDATION_INTERVAL:-2000}"
export N019_VOCODER_SELECTION_POLICY=mos_offline
export N019_VOCODER_EARLY_STOP_PATIENCE=0
export N019_VOCODER_INIT_GENERATOR="$INIT"
export N019_VOCODER_INIT_GENERATOR_SHA256="$INIT_SHA"

bash "$ROOT/scripts/run_vocoder_ddp.sh"
python "$ROOT/scripts/extract_last_generator_remote.py" \
  --source "$OUT/last.pt" \
  --out "$OUT/generator_final.pt"
sha256sum \
  "$INIT" \
  "$OUT/last.pt" \
  "$OUT/generator_final.pt" \
  "$OUT"/snapshots/generator_step*.pt \
  | tee "$OUT/final_sha256.txt"
echo "N019_2X_DIAG_COMPLETE out=$OUT"
