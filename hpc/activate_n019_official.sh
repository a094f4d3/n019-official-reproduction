#!/usr/bin/env bash

DTKROOT=/public/software/compiler/dtk-26.04
HYHAL_PATH=/opt/hyhal

# SCNet login sessions do not always export the `module` shell function.
# Reproduce the DTK 26.04 modulefile deterministically.
export DTKROOT
export AMDGPU_TARGETS="gfx906;gfx926;gfx928;gfx936"
export MIOPEN_FIND_MODE=3
export HIP_PATH="$DTKROOT/hip"
export ROCM_PATH="$DTKROOT"
export HYHAL_PATH
export PATH="$DTKROOT/bin:$DTKROOT/llvm/bin:$DTKROOT/hip/bin:$DTKROOT/hip/bin/hipify:$HYHAL_PATH/bin:$DTKROOT/opencl/bin:$PATH"
export LD_LIBRARY_PATH="$DTKROOT/hip/lib:$DTKROOT/llvm/lib:$DTKROOT/lib:$DTKROOT/lib64:$HYHAL_PATH/lib:$HYHAL_PATH/lib64:$DTKROOT/opencl/lib:${LD_LIBRARY_PATH:-}"
export LIBRARY_PATH="$DTKROOT/opencl/lib:${LIBRARY_PATH:-}"
export C_INCLUDE_PATH="$DTKROOT/include:$DTKROOT/llvm/include:$HYHAL_PATH/include:$DTKROOT/opencl/include:${C_INCLUDE_PATH:-}"
export CPLUS_INCLUDE_PATH="$DTKROOT/include:$DTKROOT/llvm/include:$HYHAL_PATH/include:$DTKROOT/opencl/include:${CPLUS_INCLUDE_PATH:-}"

if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  candidate_code_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  candidate_voice_root="$(cd "$candidate_code_root/../.." && pwd)"
  if [[ -d "$candidate_voice_root/code/n019_official" ]]; then
    export N019_VOICE_ROOT="$candidate_voice_root"
  fi
fi

if [[ -z "${N019_VOICE_ROOT:-}" ]]; then
  for candidate in \
    /mnt/data/voice_projects \
    "/public/home/$(id -un)/voice_projects" \
    "$HOME/voice_projects"; do
    if [[ -d "$candidate/code/n019_official" ]]; then
      export N019_VOICE_ROOT="$candidate"
      break
    fi
  done
fi

if [[ -z "${N019_VOICE_ROOT:-}" ]]; then
  echo "Cannot locate voice_projects under /mnt/data, /public/home, or HOME" >&2
  return 1 2>/dev/null || exit 1
fi

export N019_OFFICIAL_ROOT="${N019_OFFICIAL_ROOT:-${candidate_code_root:-$N019_VOICE_ROOT/code/n019_official}}"
export N019_BASE_ENV="$N019_VOICE_ROOT/miniconda3/envs/py311"
export N019_ENV="$N019_VOICE_ROOT/envs/n019"
export N019_OFFICIAL_DATA="$N019_VOICE_ROOT/data/n019_official"
export N019_OFFICIAL_MODELS="$N019_VOICE_ROOT/models/n019_official"
export N019_OFFICIAL_LOGS="$N019_VOICE_ROOT/logs/n019_official"
export N019_OFFICIAL_RUNS="$N019_VOICE_ROOT/runs/n019_official"
if [[ -z "${SLURM_JOB_ID:-}" ]]; then
  export TMPDIR="$N019_VOICE_ROOT/tmp"
fi

if [[ ! -x "$N019_ENV/bin/python" ]]; then
  echo "Missing N019 env: $N019_ENV" >&2
  return 1 2>/dev/null || exit 1
fi

export PATH="$N019_ENV/bin:$N019_BASE_ENV/bin:$PATH"
export LD_LIBRARY_PATH="$N019_ENV/lib:$N019_BASE_ENV/lib:${LD_LIBRARY_PATH:-}"
export CPATH="$N019_ENV/include:$N019_BASE_ENV/include:${CPATH:-}"
export LIBRARY_PATH="$N019_ENV/lib:$N019_BASE_ENV/lib:${LIBRARY_PATH:-}"
export PYTHONPATH="$N019_OFFICIAL_ROOT/compat:$N019_OFFICIAL_ROOT/src:${PYTHONPATH:-}"

export HF_HOME="$N019_VOICE_ROOT/hf_cache/n019_official"
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export TOKENIZERS_PARALLELISM=false

mkdir -p \
  "$N019_OFFICIAL_DATA" \
  "$N019_OFFICIAL_MODELS" \
  "$N019_OFFICIAL_LOGS" \
  "$N019_OFFICIAL_RUNS" \
  "$TMPDIR" \
  "$HF_HOME"

echo "N019 official environment: $N019_ENV"
echo "N019_VOICE_ROOT=$N019_VOICE_ROOT"
echo "N019_OFFICIAL_ROOT=$N019_OFFICIAL_ROOT"
