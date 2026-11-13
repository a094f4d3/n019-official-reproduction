#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
WAV_SCP="$VPC_ROOT/libri_test_n019_ext102k/wav.scp"
OUT="$N019_OFFICIAL_RUNS/eval/du_pred_nt_ext102k/dcu_utmos_smoke"
UTMOS_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"

export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"

test "$(wc -l < "$WAV_SCP")" = 1934
test -f "$UTMOS_CHECKPOINT"
mkdir -p "$OUT"
head -n 2 "$WAV_SCP" > "$OUT/wav.scp"

hostname
timeout --signal=KILL 300 python -u - <<'PY'
import torch

print(f"cuda_available={torch.cuda.is_available()}", flush=True)
print(f"device_name={torch.cuda.get_device_name(0)}", flush=True)
x = torch.randn(1024, 1024, device="cuda")
torch.cuda.synchronize()
print(f"tiny_matmul={float((x @ x).sum())}", flush=True)
torch.cuda.synchronize()
print("DCU_TINY_OK", flush=True)
PY

python -u -m n019.eval_mos \
  --backend utmos \
  --wav-scp "$OUT/wav.scp" \
  --vpc-data-root "$VPC_ROOT" \
  --code-source "$ROOT/vendor/UTMOS22-demo" \
  --checkpoint "$UTMOS_CHECKPOINT" \
  --device cuda \
  --out "$OUT/UTMOS.json" \
  > "$OUT/UTMOS.log" 2>&1

sha256sum "$OUT/wav.scp" "$OUT/UTMOS.json"
echo "UTMOS_DCU_SMOKE_COMPLETE out=$OUT"
