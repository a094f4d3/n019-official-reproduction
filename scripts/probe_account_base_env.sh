#!/usr/bin/env bash

set -u

module load compiler/dtk/26.04
PY="$HOME/voice_projects/miniconda3/envs/py311/bin/python"
export LD_LIBRARY_PATH="$HOME/voice_projects/miniconda3/envs/py311/lib:${LD_LIBRARY_PATH:-}"

echo "HOST=$(hostname) USER=$(id -un)"
if [[ ! -x "$PY" ]]; then
  echo "MISSING $PY"
  exit 1
fi

"$PY" - <<'PY'
import sys
print("python", sys.version.split()[0])
for name in [
    "torch",
    "torchaudio",
    "transformers",
    "sklearn",
    "librosa",
    "soundfile",
    "numpy",
    "scipy",
    "huggingface_hub",
    "speechbrain",
    "hyperpyyaml",
    "kaldiio",
]:
    try:
        module = __import__(name)
        print(name, getattr(module, "__version__", "unknown"))
    except Exception as exc:
        print(name, "IMPORT_FAILED", repr(exc))
PY

if [[ -x "$HOME/voice_projects/miniconda3/envs/py311/bin/ffmpeg" ]]; then
  "$HOME/voice_projects/miniconda3/envs/py311/bin/ffmpeg" -version | head -1
else
  echo "ffmpeg MISSING"
fi
