#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

export N019_DATA_SUFFIX="${N019_DATA_SUFFIX:?Set N019_DATA_SUFFIX}"
export N019_VPC_DATA="${N019_VPC_DATA:?Set N019_VPC_DATA}"
export N019_WNT_S_MODEL="${N019_WNT_S_MODEL:?Set N019_WNT_S_MODEL}"
export N019_WNT_ATTACKS=S
export N019_WNT_OUT="${N019_WNT_OUT:?Set N019_WNT_OUT}"

bash "$ROOT/scripts/evaluate_wnt_remote.sh"
