#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SRC="$N019_OFFICIAL_RUNS/vocoder_nt_paperfix"
DST="$N019_OFFICIAL_RUNS/vocoder_nt_paperfix_ext"
SOURCE_LAST_SHA="c40b745ade7caaf29c2abc7a8ea6ad271f2c8a11ae904cd9dc8a9c370276de5c"
SOURCE_BEST_SHA="f1735e757ecfc4bfb6a230ae26219058e6aed8bef18656bb2b694cc89ed070d9"

test -f "$SRC/last.pt"
test -f "$SRC/best.pt"
test "$(sha256sum "$SRC/last.pt" | awk '{print $1}')" = "$SOURCE_LAST_SHA"
test "$(sha256sum "$SRC/best.pt" | awk '{print $1}')" = "$SOURCE_BEST_SHA"

mkdir -p "$DST"
if [[ ! -f "$DST/last.pt" ]]; then
  cp --reflink=auto -p "$SRC/last.pt" "$DST/last.pt"
  cp -p "$SRC/best.pt" "$SRC/meta.json" "$SRC/training_log.jsonl" "$DST/"
  test "$(sha256sum "$DST/last.pt" | awk '{print $1}')" = "$SOURCE_LAST_SHA"
  test "$(sha256sum "$DST/best.pt" | awk '{print $1}')" = "$SOURCE_BEST_SHA"
fi

export N019_NPROC=2
export N019_VOCODER_TYPE=nt
export N019_VOCODER_RUN_NAME=vocoder_nt_paperfix_ext
export N019_VOCODER_OUT="$DST"
export N019_VOCODER_STEPS="${N019_VOCODER_STEPS:-110000}"
export N019_VOCODER_MAX_HOURS="${N019_VOCODER_MAX_HOURS:-7.5}"
export N019_VOCODER_CHECKPOINT_INTERVAL="${N019_VOCODER_CHECKPOINT_INTERVAL:-2000}"
export N019_VOCODER_KEEP_INTERVAL="${N019_VOCODER_KEEP_INTERVAL:-50000}"
export N019_VOCODER_VALIDATION_INTERVAL="${N019_VOCODER_VALIDATION_INTERVAL:-2000}"
export N019_VOCODER_EARLY_STOP_MIN_STEPS="${N019_VOCODER_EARLY_STOP_MIN_STEPS:-20000}"
export N019_VOCODER_EARLY_STOP_PATIENCE="${N019_VOCODER_EARLY_STOP_PATIENCE:-100}"
export N019_VOCODER_EARLY_STOP_MIN_DELTA="${N019_VOCODER_EARLY_STOP_MIN_DELTA:-0.001}"
export N019_VOCODER_RESUME_CONVERGED=1

bash "$ROOT/scripts/run_vocoder_ddp.sh"
python "$ROOT/scripts/extract_last_generator_remote.py" \
  --source "$DST/last.pt" \
  --out "$DST/generator_final.pt"
sha256sum "$DST/last.pt" "$DST/best.pt" "$DST/generator_final.pt" \
  | tee "$DST/final_sha256.txt"
echo "VOCODER_NT_PAPERFIX_EXT_COMPLETE out=$DST"
