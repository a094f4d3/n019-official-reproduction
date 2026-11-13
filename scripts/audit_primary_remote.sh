#!/usr/bin/env bash

set -u

echo "HOST=$(hostname)"
echo "USER=$(id -un)"
echo "DATE=$(date -Is)"

echo "---DISK---"
df -h "$HOME"
quota -s 2>/dev/null || true

echo "---VOICE_PROJECTS---"
timeout 20s du -sh "$HOME/voice_projects" 2>/dev/null \
  || echo "du timed out or failed"
find "$HOME/voice_projects" -maxdepth 3 -type d -printf '%p\n' 2>/dev/null \
  | sort | head -160

echo "---TOOLS---"
for tool in git wget curl unzip tar ffmpeg rsync zstd module; do
  printf '%s=' "$tool"
  command -v "$tool" || true
done

echo "---ENV---"
for path in \
  "$HOME/voice_projects/miniconda3/envs/py311/bin/python" \
  "$HOME/voice_projects/envs/n019/bin/python"; do
  if [[ -x "$path" ]]; then
    echo "FOUND $path"
    "$path" -c \
      'import platform,sys; print(platform.python_version()); print(sys.executable)' \
      2>&1 || true
  else
    echo "MISSING $path"
  fi
done

echo "---OFFICIAL_DIRS---"
for path in \
  "$HOME/voice_projects/code/n019_official" \
  "$HOME/voice_projects/data/n019_official" \
  "$HOME/voice_projects/models/n019_official" \
  "$HOME/voice_projects/logs/n019_official" \
  "$HOME/voice_projects/runs/n019_official"; do
  if [[ -e "$path" ]]; then
    echo "EXISTS $path"
    timeout 10s du -sh "$path" 2>/dev/null \
      || echo "du timed out or failed"
    find "$path" -maxdepth 2 -mindepth 1 -printf '%y %p\n' 2>/dev/null \
      | sort | head -80
  else
    echo "MISSING $path"
  fi
done

echo "---OLD_SOURCES---"
for path in \
  "$HOME/voice_projects/data/n019/raw/test-clean.tar.gz" \
  "$HOME/voice_projects/data/n019/raw/libritts-train-clean-100.tar.gz" \
  "$HOME/voice_projects/models/n019/hubert/pytorch_model.bin" \
  "$HOME/voice_projects/models/n019/wpro/model.safetensors"; do
  if [[ -e "$path" ]]; then
    stat -c '%n %s bytes' "$path"
  else
    echo "MISSING $path"
  fi
done

echo "---MODULES---"
module avail compiler/dtk 2>&1 | tail -30 || true

echo "---NETWORK---"
for url in \
  https://github.com \
  https://www.openslr.org \
  https://huggingface.co \
  https://hf-mirror.com; do
  code=$(curl -L -sS -o /dev/null -w '%{http_code}' --max-time 15 "$url" \
    2>/dev/null || true)
  echo "$url HTTP=$code"
done
