#!/usr/bin/env bash

set -u

for path in \
  "$HOME/voice_projects/envs/n019/bin/ffmpeg" \
  "$HOME/voice_projects/envs/n019/bin/ffprobe" \
  "$HOME/voice_projects/miniconda3/envs/py311/bin/ffmpeg" \
  "$HOME/voice_projects/miniconda3/envs/py311/bin/ffprobe" \
  "$HOME/voice_projects/miniconda3/bin/conda"; do
  if [[ -e "$path" ]]; then
    stat -c '%n %s bytes' "$path"
  else
    echo "MISSING $path"
  fi
done

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

echo "---OLD_ASR---"
find "$HOME/voice_projects/models/n019/asr" -maxdepth 3 -type f \
  -printf '%p %s\n' 2>/dev/null | head -40 || true

echo "---OLD_HUBERT---"
find "$HOME/voice_projects/models/n019/hubert" -maxdepth 2 -type f \
  -printf '%p %s\n' 2>/dev/null | sort || true

echo "---OLD_WPRO---"
find "$HOME/voice_projects/models/n019/wpro" -maxdepth 2 -type f \
  -printf '%p %s\n' 2>/dev/null | sort || true

echo "---CONDA---"
"$HOME/voice_projects/miniconda3/bin/conda" --version 2>&1 || true
"$HOME/voice_projects/miniconda3/bin/conda" config --show channels 2>&1 || true
