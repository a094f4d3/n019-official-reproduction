#!/usr/bin/env bash

set -u

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT/vendor/Voice-Privacy-Challenge-2024"

echo "---REQUIREMENTS_FILES---"
find . -maxdepth 2 -iname '*requirements*' -o -iname 'environment*.yml' \
  | sort

echo "---IMPORTS---"
python - <<'PY'
modules = [
    "speechbrain",
    "hyperpyyaml",
    "kaldiio",
    "pytorch_lightning",
    "webdataset",
    "asteroid",
    "pystoi",
    "fasteners",
    "gdown",
]
for name in modules:
    try:
        module = __import__(name)
        version = getattr(module, "__version__", "unknown")
        print(name, "OK", version)
    except Exception as exc:
        print(name, "MISSING", repr(exc))
PY

echo "---PIP_CHECK---"
python -m pip check || true

echo "---EVAL_HELP---"
python run_evaluation.py --help 2>&1 | head -100 || true
