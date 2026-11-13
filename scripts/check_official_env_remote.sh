#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"

echo "PYTHON=$(command -v python)"
echo "FFMPEG=$(command -v ffmpeg)"
ffmpeg -version | head -1

python - <<'PY'
import sys
import torch
import torchaudio
import transformers
import sklearn
import librosa
import soundfile
import numpy

print("python", sys.version.split()[0])
print("torch", torch.__version__)
print("hip", torch.version.hip)
print("cuda_available_login", torch.cuda.is_available())
print("torchaudio", torchaudio.__version__)
print("transformers", transformers.__version__)
print("sklearn", sklearn.__version__)
print("librosa", librosa.__version__)
print("soundfile", soundfile.__version__)
print("numpy", numpy.__version__)
PY

cd "$ROOT"
python -m compileall -q src tests
echo "COMPILEALL_OK"
