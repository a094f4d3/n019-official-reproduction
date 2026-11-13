#!/usr/bin/env bash

set -euo pipefail

ACCOUNT=$(id -un)
ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
BASE_ENV="$HOME/voice_projects/miniconda3/envs/py311"
N019_ENV="$HOME/voice_projects/envs/n019"

if [[ -f "$ROOT/hpc/activate_n019_official.sh" ]]; then
  source "$ROOT/hpc/activate_n019_official.sh" >/dev/null
fi

if command -v module >/dev/null 2>&1; then
  module load compiler/dtk/26.04 >/dev/null 2>&1 || true
fi

echo "account=$ACCOUNT"
echo "host=$(hostname)"
echo "date=$(date -Is)"
echo "home=$HOME"
echo "project_exists=$([[ -d "$ROOT" ]] && echo yes || echo no)"
echo "base_env_python=$([[ -x "$BASE_ENV/bin/python" ]] && echo yes || echo no)"
echo "n019_env_python=$([[ -x "$N019_ENV/bin/python" ]] && echo yes || echo no)"

echo "storage_begin"
df -h "$HOME" || true
df -P -B1 "$HOME" || true
if command -v quota >/dev/null 2>&1; then
  quota -s 2>&1 || true
fi
if command -v lfs >/dev/null 2>&1; then
  lfs quota -h -u "$(id -u)" /public/home 2>&1 || true
fi
echo "storage_end"

if [[ -x "$N019_ENV/bin/python" ]]; then
  PYTHON="$N019_ENV/bin/python"
else
  PYTHON="$BASE_ENV/bin/python"
fi

if [[ -x "$PYTHON" ]]; then
  echo "python_begin"
  LD_LIBRARY_PATH="$N019_ENV/lib:$BASE_ENV/lib:${LD_LIBRARY_PATH:-}" \
    "$PYTHON" - <<'PY'
import importlib
import json
import platform

modules = [
    "torch",
    "torchaudio",
    "transformers",
    "speechbrain",
    "kaldiio",
    "hyperpyyaml",
    "sklearn",
    "librosa",
    "soundfile",
    "numpy",
]
result = {
    "python": platform.python_version(),
    "executable": __import__("sys").executable,
}
for name in modules:
    try:
        module = importlib.import_module(name)
        result[name] = getattr(module, "__version__", "unknown")
    except Exception as exc:
        result[name] = f"MISSING: {type(exc).__name__}: {exc}"
print(json.dumps(result, indent=2, ensure_ascii=True))
PY
  echo "python_end"
fi

echo "torchaudio_inventory_begin"
if [[ -x "$N019_ENV/bin/python" ]]; then
  "$N019_ENV/bin/python" - <<'PY'
import pathlib
import sysconfig

site = pathlib.Path(sysconfig.get_paths()["purelib"])
for path in sorted(site.glob("torchaudio*")):
    print(path)
PY
fi
echo "torchaudio_inventory_end"

echo "asset_sizes_begin"
if [[ -d "$DATA" ]]; then
  find "$DATA/corpora" -maxdepth 2 -type f \
    \( -name '*.tar.gz' -o -name '*.tar.zst' -o -name '*.zip' \) \
    -printf '%p %s\n' 2>/dev/null | sort
  find "$DATA/rebuilt" -maxdepth 1 -type f \
    \( -name '*.tar.gz' -o -name '*.tar.zst' -o -name '*.zip' \) \
    -printf '%p %s\n' 2>/dev/null | sort
fi
echo "asset_sizes_end"

echo "audit_complete"
