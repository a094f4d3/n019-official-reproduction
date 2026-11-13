#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SRC="${N019_2X_CONT_SOURCE:-$N019_OFFICIAL_RUNS/vocoder_nt_2x_diag/last.pt}"
SRC_SHA="6c0837065c1612578d21285127c7c1e8152e2bd7e7e1d19d3f0197a7ab97a0f4"
OUT="${N019_2X_CONT_OUT:-$N019_OFFICIAL_RUNS/vocoder_nt_2x_cont16k}"

test -f "$SRC" || {
  echo "Missing continuation source checkpoint: $SRC" >&2
  exit 1
}
test "$(sha256sum "$SRC" | awk '{print $1}')" = "$SRC_SHA" || {
  echo "Unexpected continuation source SHA256: $SRC" >&2
  exit 1
}

if [[ -e "$OUT/last.pt" ]]; then
  echo "Refusing to overwrite a continued run: $OUT" >&2
  exit 1
fi
if [[ -d "$OUT" ]] && find "$OUT" -mindepth 1 -print -quit | grep -q .; then
  echo "Refusing to use non-empty continuation output: $OUT" >&2
  exit 1
fi

mkdir -p "$OUT"
cp --reflink=auto "$SRC" "$OUT/last.pt"
test "$(sha256sum "$OUT/last.pt" | awk '{print $1}')" = "$SRC_SHA" || {
  echo "Copied continuation checkpoint SHA256 mismatch" >&2
  exit 1
}

export N019_NPROC="${N019_2X_CONT_NPROC:-2}"
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RUN_NAME=vocoder_nt_2x_cont16k
export N019_VOCODER_OUT="$OUT"
export N019_VOCODER_STEPS="${N019_2X_CONT_STEPS:-33000}"
export N019_VOCODER_MAX_HOURS="${N019_2X_CONT_MAX_HOURS:-1.65}"
export N019_VOCODER_CHECKPOINT_INTERVAL="${N019_2X_CONT_CHECKPOINT_INTERVAL:-2000}"
export N019_VOCODER_GENERATOR_SNAPSHOT_INTERVAL="${N019_2X_CONT_SNAPSHOT_INTERVAL:-2000}"
export N019_VOCODER_KEEP_INTERVAL="${N019_2X_CONT_KEEP_INTERVAL:-10000}"
export N019_VOCODER_VALIDATION_INTERVAL="${N019_2X_CONT_VALIDATION_INTERVAL:-2000}"
export N019_VOCODER_SELECTION_POLICY=mos_offline
export N019_VOCODER_EARLY_STOP_PATIENCE=0

bash "$ROOT/scripts/run_vocoder_ddp.sh"
python "$ROOT/scripts/extract_last_generator_remote.py" \
  --source "$OUT/last.pt" \
  --out "$OUT/generator_final.pt"
sha256sum \
  "$SRC" \
  "$OUT/last.pt" \
  "$OUT/generator_final.pt" \
  "$OUT"/snapshots/generator_step*.pt \
  | tee "$OUT/final_sha256.txt"
echo "N019_2X_CONTINUE_COMPLETE out=$OUT"
