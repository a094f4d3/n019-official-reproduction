#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

VPC_DATA="${N019_VPC_DATA:-$N019_OFFICIAL_DATA/vpc/data}"
BASE_VPC_DATA="${N019_WNT_BASE_VPC_DATA:-$VPC_DATA}"
MODELS="$N019_OFFICIAL_MODELS"
SUFFIX="${N019_DATA_SUFFIX:-_n019}"
RUN_NAME="${N019_RUN_NAME:-wnt}"
ATTACKS="${N019_WNT_ATTACKS:-I L}"
OUT="${N019_WNT_OUT:-$N019_OFFICIAL_RUNS/eval/$RUN_NAME}"
WNT_MODEL="${N019_WNT_MODEL:-$MODELS/wpro}"
WNT_S_MODEL="${N019_WNT_S_MODEL:-}"

mkdir -p "$OUT"

for attack in $ATTACKS; do
  model="$WNT_MODEL"
  case "$attack" in
    I) enroll_suffix="" ;;
    L) enroll_suffix="$SUFFIX" ;;
    S)
      enroll_suffix="$SUFFIX"
      if [[ -z "$WNT_S_MODEL" ]]; then
        echo "N019_WNT_S_MODEL must point to the fine-tuned S attack model" >&2
        exit 1
      fi
      model="$WNT_S_MODEL"
      ;;
    *)
      echo "Unknown W-NT attack $attack" >&2
      exit 1
      ;;
  esac
  for required_model in \
    "$model/config.json" \
    "$model/model.safetensors" \
    "$model/spk_embeddings.py"; do
    if [[ ! -f "$required_model" ]]; then
      echo "Missing W-NT model input for $attack: $required_model" >&2
      exit 1
    fi
  done
  if [[ "$attack" == "I" ]]; then
    enroll_root="$BASE_VPC_DATA"
  else
    enroll_root="$VPC_DATA"
  fi
  for gender in f m; do
    python -u -m n019.eval_wnt \
      --vpc-data-root "$VPC_DATA" \
      --enroll-dir "$enroll_root/libri_test_enrolls$enroll_suffix" \
      --trial-dir "$VPC_DATA/libri_test_trials_${gender}$SUFFIX" \
      --trials "$BASE_VPC_DATA/libri_test_trials_${gender}/trials" \
      --model "$model" \
      --device cuda \
      --attack-label "$attack" \
      --out "$OUT/libri_test_trials_${gender}_${attack}.json"
  done
done

python - "$OUT" <<'PY'
import json
import os
import sys
from pathlib import Path

out = Path(sys.argv[1])
summary = {"attacks": {}}
for attack in os.environ.get("N019_WNT_ATTACKS", "I L").split():
    female = json.loads(
        (out / f"libri_test_trials_f_{attack}.json").read_text()
    )
    male = json.loads(
        (out / f"libri_test_trials_m_{attack}.json").read_text()
    )
    summary["attacks"][attack] = {
        "female_eer_percent": female["eer_percent"],
        "male_eer_percent": male["eer_percent"],
        "mean_eer_percent": (
            female["eer_percent"] + male["eer_percent"]
        ) / 2,
    }
summary["suffix"] = (
    out / "libri_test_trials_f_L.json"
).exists() and json.loads(
    (out / "libri_test_trials_f_L.json").read_text()
)["enroll_dir"].split("libri_test_enrolls")[-1] or ""
(out / "summary.json").write_text(
    json.dumps(summary, indent=2) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2))
PY
