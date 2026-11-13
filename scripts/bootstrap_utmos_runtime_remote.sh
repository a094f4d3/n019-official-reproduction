#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"
SUFFIX="_n019_paperfix"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
PROBE_DIR="$N019_OFFICIAL_RUNS/eval/utmos_runtime_probe"
FAIRSEQ_ARCHIVE="$N019_VOICE_ROOT/tmp/fairseq-0.12.2.tar.gz"
FAIRSEQ_SHA256="34f1b18426bf3844714534162f065ab733e049597476daa35fffb4d06a92b524"
FAIRSEQ_URL="https://pypi.tuna.tsinghua.edu.cn/packages/30/36/db42846570f479ac859be3b48d8b47f2ae9b0b9c77487a512f2f2ecbcb6b/fairseq-0.12.2.tar.gz"

export PYTHONPATH="$OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"

runtime_ready() {
  python - <<'PY'
import fairseq
import hydra
import omegaconf
import pytorch_lightning
import torch
import numpy

print(
    "UTMOS_RUNTIME_READY",
    f"fairseq={fairseq.__version__}",
    f"hydra={hydra.__version__}",
    f"omegaconf={omegaconf.__version__}",
    f"pytorch_lightning={pytorch_lightning.__version__}",
    f"torch={torch.__version__}",
    f"numpy={numpy.__version__}",
)
PY
}

if ! runtime_ready >/dev/null 2>&1; then
  mkdir -p "$OVERLAY"
  python -m pip install \
    --no-cache-dir \
    --no-deps \
    --upgrade \
    --target "$OVERLAY" \
    "setuptools<70" \
    wheel \
    "Cython<3" \
    "hydra-core==1.0.7" \
    "omegaconf==2.0.6" \
    "antlr4-python3-runtime==4.8" \
    "pytorch-lightning==1.5.10" \
    "torchmetrics==0.7.2" \
    "pyDeprecate==0.3.1" \
    "bitarray==2.6.1" \
    "sacrebleu==2.0.0" \
    "tqdm==4.63.0" \
    "regex==2022.9.11" \
    "portalocker==2.4.0" \
    "tabulate==0.8.9" \
    "colorama==0.4.4" \
    "appdirs==1.4.4" \
    "cffi==1.17.1"

  if [[ ! -f "$FAIRSEQ_ARCHIVE" ]]; then
    curl -L --fail --retry 10 --retry-delay 5 \
      -o "$FAIRSEQ_ARCHIVE.part" "$FAIRSEQ_URL"
    mv "$FAIRSEQ_ARCHIVE.part" "$FAIRSEQ_ARCHIVE"
  fi
  echo "$FAIRSEQ_SHA256  $FAIRSEQ_ARCHIVE" | sha256sum -c -

  FAIRSEQ_SRC="$N019_VOICE_ROOT/tmp/fairseq-0.12.2-src"
  rm -rf "$FAIRSEQ_SRC"
  mkdir -p "$FAIRSEQ_SRC"
  tar -xzf "$FAIRSEQ_ARCHIVE" -C "$FAIRSEQ_SRC" --strip-components=1
  python "$ROOT/scripts/patch_fairseq_sdist.py" \
    --setup "$FAIRSEQ_SRC/setup.py"
  python -m pip install \
    --no-cache-dir \
    --no-deps \
    --no-build-isolation \
    --upgrade \
    --target "$OVERLAY" \
    "$FAIRSEQ_SRC"

  for tree in fairseq hydra omegaconf; do
    if [[ -d "$OVERLAY/$tree" ]]; then
      python "$ROOT/scripts/patch_fairseq_py311.py" \
        --tree "$OVERLAY/$tree"
    fi
  done
fi

runtime_ready

test "$(wc -l < "$VPC_ROOT/libri_test$SUFFIX/wav.scp")" = 1934
rm -rf "$PROBE_DIR"
mkdir -p "$PROBE_DIR"

python -m n019.eval_mos \
  --backend utmos \
  --wav-scp "$VPC_ROOT/libri_test$SUFFIX/wav.scp" \
  --vpc-data-root "$VPC_ROOT" \
  --code-source "$ROOT/vendor/UTMOS22-demo" \
  --checkpoint "$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt" \
  --out "$PROBE_DIR/UTMOS.json" \
  --device cuda \
  --limit 1

python - "$PROBE_DIR/UTMOS.json" <<'PY'
import json
import math
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if int(report["count"]) != 1:
    raise SystemExit(f"UTMOS probe count={report['count']}, expected 1")
score = float(report["mean"])
if not math.isfinite(score) or not 0.0 <= score <= 5.0:
    raise SystemExit(f"UTMOS probe score out of range: {score}")
print(f"UTMOS_PROBE_OK score={score:.12f} count=1")
PY

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
chown -R "$owner" "$OVERLAY" "$PROBE_DIR"
find "$OVERLAY" -type f -print0 | sort -z | xargs -0 sha256sum \
  > "$PROBE_DIR/overlay_SHA256SUMS.txt"
echo "UTMOS_RUNTIME_BOOTSTRAP_COMPLETE overlay=$OVERLAY"
