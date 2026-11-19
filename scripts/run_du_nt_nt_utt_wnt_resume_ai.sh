#!/usr/bin/env bash

set -euo pipefail

ROOT="/public/home/a094f4d10/voice_projects/code/n019_official"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="/public/home/a094f4d10/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

export N019_VPC_DATA="$N019_OFFICIAL_DATA/vpc_ai/data"
export N019_DATA_SUFFIX="_n019_du_nt_nt_utt_20261117"
export N019_RUN_NAME="du_nt_nt_utt_20261117_wnt"
export N019_WNT_ATTACKS="I L"
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$N019_OFFICIAL_RUNS/eval/du_nt_nt_utt_20261117_wnt"

if [[ "$(id -u)" == "0" ]]; then
  owner="$(stat -c '%u:%g' "$N019_OFFICIAL_RUNS")"
  trap 'chown -R "$owner" "$N019_WNT_OUT" 2>/dev/null || true' EXIT
fi

bash "$ROOT/scripts/evaluate_wnt_remote.sh"

sha256sum "$N019_WNT_OUT/summary.json"
echo "N019_DU_NT_NT_UTT_WNT_RESUME_COMPLETE out=$N019_WNT_OUT"
