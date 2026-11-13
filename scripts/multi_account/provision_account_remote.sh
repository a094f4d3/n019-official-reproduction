#!/usr/bin/env bash

set -euo pipefail

ACCOUNT=$(id -un)
case "$ACCOUNT" in
  a094f4d3|a094f4d4|a094f4d5|a094f4d6|a094f4d7) ;;
  *)
    echo "Refusing unexpected SCNet account: $ACCOUNT" >&2
    exit 2
    ;;
esac

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
RUNS="$HOME/voice_projects/runs/n019_official"
BASE_ENV="$HOME/voice_projects/miniconda3/envs/py311"
N019_ENV="$HOME/voice_projects/envs/n019"

test -x "$BASE_ENV/bin/python"

mkdir -p \
  "$ROOT"/{src,configs,hpc,tests,docs,vendor,compat,scripts,audit} \
  "$DATA"/{corpora/librispeech,corpora/libritts,vpc,rebuilt,processed,manifests} \
  "$MODELS"/{hubert,wpro,vpc,mos} \
  "$LOGS" \
  "$RUNS"

if [[ ! -x "$N019_ENV/bin/python" ]]; then
  "$BASE_ENV/bin/python" -m venv --system-site-packages "$N019_ENV"
fi

"$N019_ENV/bin/python" -m pip install \
  --disable-pip-version-check \
  --no-deps \
  "speechbrain==0.5.16" \
  "hyperpyyaml==1.2.2" \
  "kaldiio==2.18.0" \
  "sentencepiece==0.2.0"

TORCHAUDIO_TARBALL=${N019_TORCHAUDIO_TARBALL:-$ROOT/compat/torchaudio_scnet_compat.tar.gz}
if [[ -s "$TORCHAUDIO_TARBALL" ]] \
  && [[ ! -f "$ROOT/compat/torchaudio/__init__.py" ]]; then
  tar -xzf "$TORCHAUDIO_TARBALL" -C "$ROOT/compat"
fi

cat > "$ROOT/hpc/activate_n019_official.sh" <<'EOF'
#!/usr/bin/env bash

if command -v module >/dev/null 2>&1; then
  module load compiler/dtk/26.04
fi

export N019_OFFICIAL_ROOT="$HOME/voice_projects/code/n019_official"
export N019_BASE_ENV="$HOME/voice_projects/miniconda3/envs/py311"
export N019_ENV="$HOME/voice_projects/envs/n019"
export N019_OFFICIAL_DATA="$HOME/voice_projects/data/n019_official"
export N019_OFFICIAL_MODELS="$HOME/voice_projects/models/n019_official"
export N019_OFFICIAL_LOGS="$HOME/voice_projects/logs/n019_official"
export N019_OFFICIAL_RUNS="$HOME/voice_projects/runs/n019_official"

if [[ ! -x "$N019_ENV/bin/python" ]]; then
  echo "Missing N019 env: $N019_ENV" >&2
  return 1 2>/dev/null || exit 1
fi

export PATH="$N019_ENV/bin:$N019_BASE_ENV/bin:$PATH"
export LD_LIBRARY_PATH="$N019_ENV/lib:$N019_BASE_ENV/lib:${LD_LIBRARY_PATH:-}"
export CPATH="$N019_ENV/include:$N019_BASE_ENV/include:${CPATH:-}"
export LIBRARY_PATH="$N019_ENV/lib:$N019_BASE_ENV/lib:${LIBRARY_PATH:-}"
export PYTHONPATH="$N019_OFFICIAL_ROOT/compat:$N019_OFFICIAL_ROOT/src:${PYTHONPATH:-}"

export HF_HOME="$HOME/voice_projects/hf_cache/n019_official"
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export TOKENIZERS_PARALLELISM=false

mkdir -p \
  "$N019_OFFICIAL_DATA" \
  "$N019_OFFICIAL_MODELS" \
  "$N019_OFFICIAL_LOGS" \
  "$N019_OFFICIAL_RUNS" \
  "$HF_HOME"

echo "N019 official environment: $N019_ENV"
echo "N019_OFFICIAL_ROOT=$N019_OFFICIAL_ROOT"
EOF

chmod +x "$ROOT/hpc/activate_n019_official.sh"
chmod +x "$ROOT/scripts/"*.sh "$ROOT/scripts/multi_account/"*.sh 2>/dev/null || true

cat > "$ROOT/audit/provisioned_at.txt" <<EOF
account=$ACCOUNT
host=$(hostname)
date=$(date -Is)
base_env=$BASE_ENV
n019_env=$N019_ENV
EOF

echo "PROVISION_OK account=$ACCOUNT root=$ROOT"
