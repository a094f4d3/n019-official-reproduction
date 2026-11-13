#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
RUNS="$HOME/voice_projects/runs/n019_official"
OLD_CODE="$HOME/voice_projects/code/n019_repro"
OLD_DATA="$HOME/voice_projects/data/n019"
OLD_MODELS="$HOME/voice_projects/models/n019"

mkdir -p \
  "$ROOT"/{src,configs,hpc,tests,docs,vendor,compat,scripts,audit} \
  "$DATA"/{corpora/librispeech,corpora/libritts,vpc,rebuilt,processed,manifests} \
  "$MODELS"/{hubert,wpro,vpc,mos} \
  "$LOGS" \
  "$RUNS"

cat > "$ROOT/hpc/activate_n019_official.sh" <<'EOF'
#!/usr/bin/env bash

module load compiler/dtk/26.04

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

if [[ -d "$OLD_CODE/src" ]]; then
  rsync -a \
    --exclude 'runs/' \
    --exclude 'data/' \
    --exclude 'assets/' \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    "$OLD_CODE/src/" "$ROOT/src/"
fi

for dir in compat hpc tests; do
  if [[ -d "$OLD_CODE/$dir" ]]; then
    rsync -a \
      --exclude '__pycache__/' \
      --exclude '*.pyc' \
      "$OLD_CODE/$dir/" "$ROOT/$dir/"
  fi
done

if [[ -f "$OLD_CODE/requirements-n019.txt" ]]; then
  cp -f "$OLD_CODE/requirements-n019.txt" "$ROOT/requirements-n019.txt"
fi

link_or_keep() {
  local source_path=$1
  local target_path=$2
  if [[ ! -e "$target_path" ]]; then
    ln "$source_path" "$target_path"
    echo "HARDLINK $target_path <- $source_path"
  else
    echo "KEEP $target_path"
  fi
}

if [[ -f "$OLD_DATA/raw/test-clean.tar.gz" ]]; then
  link_or_keep \
    "$OLD_DATA/raw/test-clean.tar.gz" \
    "$DATA/corpora/librispeech/test-clean.tar.gz"
fi

if [[ -f "$OLD_DATA/raw/libritts-train-clean-100.tar.gz" ]]; then
  link_or_keep \
    "$OLD_DATA/raw/libritts-train-clean-100.tar.gz" \
    "$DATA/corpora/libritts/train-clean-100.tar.gz"
fi

for model in hubert wpro; do
  if [[ -d "$OLD_MODELS/$model" && ! -e "$MODELS/$model/pytorch_model.bin" \
    && ! -e "$MODELS/$model/model.safetensors" ]]; then
    cp -al "$OLD_MODELS/$model/." "$MODELS/$model/"
    echo "HARDLINK_TREE $MODELS/$model <- $OLD_MODELS/$model"
  else
    echo "KEEP_OR_MISSING $MODELS/$model"
  fi
done

date -Is > "$ROOT/audit/provisioned_at.txt"
mkdir -p "$LOGS"
echo "Provision complete: $ROOT"
