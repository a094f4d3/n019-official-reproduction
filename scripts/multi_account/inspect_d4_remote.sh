#!/usr/bin/env bash

set -euo pipefail

ACCOUNT=$(id -un)
if [[ "$ACCOUNT" != "a094f4d4" ]]; then
  echo "This inspection is restricted to a094f4d4" >&2
  exit 2
fi

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
N019_ENV="$HOME/voice_projects/envs/n019"

source "$ROOT/hpc/activate_n019_official.sh"

echo "inspect_begin account=$ACCOUNT host=$(hostname) date=$(date -Is)"
echo "home_dirs_begin"
du -sh "$ROOT" "$HOME/voice_projects/envs/n019" 2>/dev/null || true
echo "home_dirs_end"

echo "other500_begin"
find "$DATA/corpora/libritts" -maxdepth 2 -type d \
  -name 'train-other-500*' -printf '%p\n' 2>/dev/null | sort
find "$DATA/corpora/libritts/LibriTTS/train-other-500" \
  -type f -name '*.wav' 2>/dev/null | wc -l
echo "other500_end"

echo "archives_begin"
find "$DATA" "$MODELS" -maxdepth 4 -type f \
  \( -name '*.tar.gz' -o -name '*.tar.zst' -o -name '*.zip' \) \
  -printf '%p %s\n' 2>/dev/null | sort
echo "archives_end"

echo "torchaudio_python_begin"
"$N019_ENV/bin/python" - <<'PY'
import importlib.metadata
import pathlib
import sysconfig

import torch
import torchaudio

print("torch", torch.__version__)
print("hip", torch.version.hip)
print("torchaudio", torchaudio.__version__)
print("torchaudio_file", torchaudio.__file__)
print("site_packages", sysconfig.get_paths()["purelib"])

try:
    dist = importlib.metadata.distribution("torchaudio")
    print("dist_version", dist.version)
    print("dist_root", dist.locate_file(""))
    direct_url = pathlib.Path(dist.locate_file("direct_url.json"))
    if direct_url.is_file():
        print("direct_url", direct_url.read_text(encoding="utf-8"))
except importlib.metadata.PackageNotFoundError:
    print("dist_metadata", "not_installed")
PY
echo "torchaudio_python_end"

echo "torchaudio_files_begin"
find \
  "$N019_ENV/lib/python3.11/site-packages" \
  "$HOME/voice_projects/miniconda3/envs/py311/lib/python3.11/site-packages" \
  -maxdepth 1 \
  \( -name 'torchaudio' -o -name 'torchaudio-*.dist-info' \) \
  -printf '%p %y\n' 2>/dev/null | sort
echo "torchaudio_files_end"

echo "torchaudio_search_begin"
for base in \
  "$HOME/voice_projects/wheels" \
  "$HOME/voice_projects/code/n019_repro/compat" \
  "$HOME/voice_projects/code/n019_repro/src" \
  "$HOME/voice_projects/envs"; do
  if [[ -e "$base" ]]; then
    find "$base" -maxdepth 4 \
      \( -name 'torchaudio' -o -name 'torchaudio-*' -o -name 'torchaudio*.whl' \) \
      -printf '%p %y %s\n' 2>/dev/null || true
  fi
done
echo "torchaudio_search_end"

echo "pip_freeze_begin"
"$N019_ENV/bin/python" -m pip freeze | \
  grep -E '^(torch|torchaudio|torchvision|speechbrain|hyperpyyaml|kaldiio|transformers)==' || true
echo "pip_freeze_end"

echo "slurm_begin"
sinfo -s || true
squeue -u "$ACCOUNT" -o '%.18i %.28j %.12T %.12P %.12b %.12l' || true
sacct -u "$ACCOUNT" -P --allocations \
  --format=JobID,JobName,State,ElapsedRaw,AllocTRES \
  | tail -20 || true
echo "slurm_end"

echo "inspect_complete"
