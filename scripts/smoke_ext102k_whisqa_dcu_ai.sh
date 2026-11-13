#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
WAV_SCP="$VPC_ROOT/libri_test_n019_ext102k/wav.scp"
OUT="$N019_OFFICIAL_RUNS/eval/du_pred_nt_ext102k/dcu_whisqa_smoke"
WHISQA_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt"
WHISPER_SMALL_PATH="$N019_VOICE_ROOT/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"

export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"
export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"
export HIP_LAUNCH_BLOCKING=1
export CUDA_LAUNCH_BLOCKING=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

test "$(wc -l < "$WAV_SCP")" = 1934
test -f "$WHISQA_CHECKPOINT"
test -f "$WHISPER_SMALL_PATH/config.json"
mkdir -p "$OUT"
head -n 2 "$WAV_SCP" > "$OUT/wav.scp"

python -u - <<'PY'
import torch

print(f"cuda_available={torch.cuda.is_available()}", flush=True)
print(f"device_count={torch.cuda.device_count()}", flush=True)
print(f"device_name={torch.cuda.get_device_name(0)}", flush=True)
x = torch.randn(1024, 1024, device="cuda")
torch.cuda.synchronize()
print(f"tiny_matmul={float((x @ x).sum())}", flush=True)
torch.cuda.synchronize()
print("DCU_TINY_OK", flush=True)
PY

python -u -m n019.eval_mos \
  --backend whisqa \
  --wav-scp "$OUT/wav.scp" \
  --vpc-data-root "$VPC_ROOT" \
  --code-source "$ROOT/vendor/WhiSQA" \
  --checkpoint "$WHISQA_CHECKPOINT" \
  --device cuda \
  --out "$OUT/WhiSQA.json" \
  > "$OUT/WhiSQA.log" 2>&1

sha256sum "$OUT/wav.scp" "$OUT/WhiSQA.json"
echo "WHISQA_DCU_SMOKE_COMPLETE out=$OUT"
