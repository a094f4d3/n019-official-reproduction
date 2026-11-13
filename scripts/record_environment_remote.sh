#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

{
  echo "host=$(hostname)"
  echo "date=$(date -Is)"
  echo "user=$(id -un)"
  echo "python=$(python --version 2>&1)"
  echo "ffmpeg=$(ffmpeg -version | head -1)"
  echo "vpc_commit=$(git -C vendor/Voice-Privacy-Challenge-2024 rev-parse HEAD)"
  python - <<'PY'
import torch
import torchaudio
import transformers
import sklearn
import librosa
import soundfile
import numpy
import scipy
import speechbrain
import kaldiio

print("torch", torch.__version__)
print("hip", torch.version.hip)
print("torchaudio", torchaudio.__version__)
print("transformers", transformers.__version__)
print("sklearn", sklearn.__version__)
print("librosa", librosa.__version__)
print("soundfile", soundfile.__version__)
print("numpy", numpy.__version__)
print("scipy", scipy.__version__)
print("speechbrain", speechbrain.__version__)
print("kaldiio", kaldiio.__version__)
PY
} > audit/environment.txt

python -m pip freeze > audit/pip_freeze.txt

find src compat hpc tests configs scripts -type f \
  ! -path '*/__pycache__/*' \
  ! -name '*.pyc' \
  -print0 \
  | sort -z \
  | xargs -0 sha256sum \
  > audit/source_tree_sha256.txt

echo "ENVIRONMENT_RECORDED"
