#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export N019_VOICE_ROOT="$(cd "$ROOT/../.." && pwd)"
source "$ROOT/hpc/activate_n019_official.sh"

export N019_NPROC=2
export N019_VOCODER_TYPE="${N019_VOCODER_TYPE:-nt}"
export N019_VOCODER_STEPS="${N019_VOCODER_STEPS:-1000}"
export N019_VOCODER_TOTAL_BATCH="${N019_VOCODER_TOTAL_BATCH:-32}"
export N019_VOCODER_MAX_HOURS="${N019_VOCODER_MAX_HOURS:-0.20}"
export N019_VOCODER_CHECKPOINT_INTERVAL="${N019_VOCODER_CHECKPOINT_INTERVAL:-500}"
export N019_VOCODER_KEEP_INTERVAL="${N019_VOCODER_KEEP_INTERVAL:-1000}"
export N019_VOCODER_VALIDATION_INTERVAL="${N019_VOCODER_VALIDATION_INTERVAL:-500}"
export N019_VOCODER_WORKERS="${N019_VOCODER_WORKERS:-4}"
if [[ "$N019_VOCODER_TYPE" == "ecapa" ]]; then
  default_run_name="vocoder_ecapa_ddp_pilot_ai_$(date +%Y%m%d_%H%M%S)"
else
  default_run_name="vocoder_nt_ddp_pilot_ai_$(date +%Y%m%d_%H%M%S)"
fi
export N019_VOCODER_RUN_NAME="${N019_VOCODER_RUN_NAME:-$default_run_name}"
export N019_PREFLIGHT_MANIFEST="${N019_PREFLIGHT_MANIFEST:-$N019_OFFICIAL_DATA/processed/units/libritts_train_clean_100/unit_records.jsonl}"

exec bash "$ROOT/scripts/run_vocoder_ddp.sh"
