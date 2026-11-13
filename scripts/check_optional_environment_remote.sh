#!/usr/bin/env bash

set -u

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

python - <<'PY'
modules = [
    "hydra",
    "omegaconf",
    "fairseq",
    "torchvision",
    "pandas",
    "pyarrow",
    "numba",
    "pyloudnorm",
    "noisereduce",
    "tensorboard",
]
for name in modules:
    try:
        module = __import__(name)
        version = getattr(module, "__version__", "unknown")
        print(name, "OK", version)
    except Exception as exc:
        print(name, "MISSING", repr(exc))
PY

echo "---WHISQA_REQUIREMENTS---"
cat vendor/WhiSQA/requirements.txt

echo "---UTMOS_REQUIREMENTS---"
sed -n '1,220p' vendor/UTMOS22/pyproject.toml
