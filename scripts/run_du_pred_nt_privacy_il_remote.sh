#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SUFFIX="${N019_DATA_SUFFIX:?Set N019_DATA_SUFFIX to the current anonymised suffix}"
VPC_DATA="${N019_VPC_DATA:?Set N019_VPC_DATA to the containing VPC data directory}"
RUN_NAME="${N019_RUN_NAME:-du_pred_nt_privacy_il}"
OUT="${N019_PRIVACY_IL_OUT:-$N019_OFFICIAL_RUNS/eval_user/$RUN_NAME}"

test -f "$VPC_DATA/libri_test/wav.scp"
test -f "$VPC_DATA/libri_test_enrolls/wav.scp"
test -f "$VPC_DATA/libri_test_trials_f/trials"
test -f "$VPC_DATA/libri_test_trials_m/trials"
test -f "$VPC_DATA/libri_test_enrolls$SUFFIX/wav.scp"
test -f "$VPC_DATA/libri_test_trials_f$SUFFIX/trials"
test -f "$VPC_DATA/libri_test_trials_m$SUFFIX/trials"

mkdir -p "$OUT"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "user=$(id -un)"
  echo "date=$(date -Is)"
  echo "suffix=$SUFFIX"
  echo "vpc_data=$VPC_DATA"
  echo "out=$OUT"
} | tee "$OUT/launch.txt"

watchdog() {
  local name="$1"
  shift
  if ! timeout --signal=KILL 300s python -c \
    "import torch; x=torch.randn(32,32,device='cuda'); print(float((x@x).sum()))"; then
    echo "DCU watchdog failed for $name" >&2
    return 124
  fi
  "$@"
}

export N019_DATA_SUFFIX="$SUFFIX"
export N019_VPC_DATA="$VPC_DATA"

if [[ "${N019_SKIP_WNT:-0}" != "1" ]]; then
  export N019_WNT_ATTACKS="${N019_WNT_ATTACKS:-I L}"
  export N019_WNT_OUT="$OUT/wnt"
  watchdog wnt bash "$ROOT/scripts/evaluate_wnt_remote.sh"
fi

if [[ "${N019_SKIP_EVPC:-0}" != "1" ]]; then
  export N019_EVPC_OUT="$OUT/evpc"
  export N019_EVPC_CONFIG="$ROOT/configs/eval_paper_test_only_privacy.yaml"
  watchdog evpc bash "$ROOT/scripts/evaluate_evpc_pre_remote.sh"
fi

python - "$OUT" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

out = Path(sys.argv[1])
evpc = json.loads((out / "evpc" / "evpc_metrics.json").read_text())
wnt = json.loads((out / "wnt" / "summary.json").read_text())
summary = {
    "E-VPC I": evpc["paper_conditions"]["I"]["mean_eer_percent"],
    "E-VPC L": evpc["paper_conditions"]["L"]["mean_eer_percent"],
    "W-NT I": wnt["attacks"]["I"]["mean_eer_percent"],
    "W-NT L": wnt["attacks"]["L"]["mean_eer_percent"],
    "suffix": evpc.get("source", ""),
    "sources": {
        "evpc": str(out / "evpc" / "evpc_metrics.json"),
        "wnt": str(out / "wnt" / "summary.json"),
    },
}
(out / "privacy_il_metrics.json").write_text(
    json.dumps(summary, indent=2) + "\n",
    encoding="utf-8",
)

paths = [
    out / "evpc" / "evpc_metrics.json",
    out / "wnt" / "summary.json",
    out / "privacy_il_metrics.json",
]
with (out / "SHA256SUMS.txt").open("w", encoding="utf-8") as handle:
    for path in paths:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        handle.write(f"{digest}  {path}\n")
print(json.dumps(summary, indent=2))
PY

sha256sum -c "$OUT/SHA256SUMS.txt"
echo "DU_PRED_NT_PRIVACY_IL_COMPLETE out=$OUT"
