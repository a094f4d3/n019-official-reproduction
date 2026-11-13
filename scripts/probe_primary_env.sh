#!/usr/bin/env bash

set -u

module load compiler/dtk/26.04

echo "---FFMPEG_WRAPPER---"
sed -n '1,80p' \
  "$HOME/voice_projects/miniconda3/envs/py311/bin/ffmpeg" 2>/dev/null || true

echo "---FFMPEG_RUN---"
"$HOME/voice_projects/miniconda3/envs/py311/bin/ffmpeg" -version \
  2>&1 | head -10 || true

echo "---N019_IMPORTS---"
"$HOME/voice_projects/envs/n019/bin/python" - <<'PY' || true
mods = [
    "torch",
    "torchaudio",
    "transformers",
    "sklearn",
    "librosa",
    "soundfile",
    "numpy",
    "scipy",
    "huggingface_hub",
    "imageio_ffmpeg",
]
for name in mods:
    try:
        mod = __import__(name)
        print(name, getattr(mod, "__version__", "unknown"))
    except Exception as exc:
        print(name, "IMPORT_FAILED", repr(exc))
PY

echo "---TORCH_DETAIL---"
"$HOME/voice_projects/envs/n019/bin/python" - <<'PY' || true
import torch
import torchaudio
print("torch", torch.__version__)
print("hip", torch.version.hip)
print("cuda_available_login", torch.cuda.is_available())
print("torchaudio", torchaudio.__version__)
PY

echo "---CONDA_LOCATION---"
find "$HOME/voice_projects/miniconda3" -maxdepth 3 -type f \
  -name conda -printf '%p\n' 2>/dev/null | head -20
