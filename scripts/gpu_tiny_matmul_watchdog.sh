#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SECONDS_LIMIT="${N019_GPU_WATCHDOG_SECONDS:-300}"
if ! [[ "$SECONDS_LIMIT" =~ ^[1-9][0-9]*$ ]]; then
  echo "N019_GPU_WATCHDOG_SECONDS must be a positive integer" >&2
  exit 1
fi

timeout --signal=KILL "$SECONDS_LIMIT" python -u - <<'PY'
import torch

if not torch.cuda.is_available():
    raise SystemExit("CUDA/DCU unavailable")
print(f"device_count={torch.cuda.device_count()}", flush=True)
print(f"device_name={torch.cuda.get_device_name(0)}", flush=True)
x = torch.randn(1024, 1024, device="cuda", dtype=torch.float32)
torch.cuda.synchronize()
print(f"tiny_matmul={float((x @ x).sum())}", flush=True)
torch.cuda.synchronize()
print("N019_GPU_TINY_MATMUL_OK", flush=True)
PY
