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
AUDIT="$ROOT/audit"
LOGS="$HOME/voice_projects/logs/n019_official"
PYTHON="$HOME/voice_projects/envs/n019/bin/python"
MODE=${N019_ASSET_MODE:-eval}

mkdir -p "$AUDIT" "$LOGS" \
  "$DATA/corpora/librispeech" "$DATA/corpora/libritts" \
  "$DATA/vpc" "$MODELS/hubert" "$MODELS/wpro" "$MODELS/vpc" "$MODELS/mos" \
  "$ROOT/vendor"

test -x "$PYTHON"

log() {
  echo "[$(date -Is)] $*"
}

github_url() {
  local path=$1
  if curl -fsSI --max-time 12 "https://github.com" >/dev/null 2>&1; then
    printf 'https://github.com/%s\n' "$path"
  elif curl -fsSI --max-time 12 \
    "https://ghproxy.net/https://github.com/${path%%/*}" >/dev/null 2>&1; then
    printf 'https://ghproxy.net/https://github.com/%s\n' "$path"
  else
    printf 'https://ghfast.top/https://github.com/%s\n' "$path"
  fi
}

sha256_of() {
  sha256sum "$1" | awk '{print $1}'
}

download_small() {
  local url=$1
  local output=$2
  local expected_sha=$3
  local label=$4

  if [[ -f "$output" ]] && [[ "$(sha256_of "$output")" == "$expected_sha" ]]; then
    log "ALREADY_OK $label"
    return 0
  fi
  if [[ -e "$output" ]]; then
    mv "$output" "$output.invalid.$(date +%Y%m%d_%H%M%S)"
  fi

  log "START $label"
  curl -fL --retry 20 --retry-delay 10 -C - \
    -o "$output.part" "$url"
  test "$(sha256_of "$output.part")" = "$expected_sha"
  mv "$output.part" "$output"
  log "DONE $label"
}

download_parallel() {
  local url=$1
  local output=$2
  local expected_md5=$3
  local label=$4

  log "START $label"
  "$PYTHON" "$ROOT/scripts/parallel_download_openslr.py" \
    --url "$url" \
    --output "$output" \
    --expected-md5 "$expected_md5" \
    --connections "${N019_DOWNLOAD_CONNECTIONS:-16}"
  log "DONE $label"
}

VPC_ARCHIVE_PATH="Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/archive/7c80e86d3a4d58b81a2f3bdc01a3508c37018be4.tar.gz"
VPC_ARCHIVE_URL=$(github_url "$VPC_ARCHIVE_PATH")
VPC_TMP="$ROOT/vendor/.vpc2024-download"
VPC_DIR="$ROOT/vendor/Voice-Privacy-Challenge-2024"

if [[ ! -f "$VPC_DIR/.upstream_commit" ]]; then
  if [[ -e "$VPC_TMP" ]]; then
    mv "$VPC_TMP" "$VPC_TMP.previous.$(date +%Y%m%d_%H%M%S)"
  fi
  mkdir -p "$VPC_TMP"
  log "START VPC repo commit"
  curl -fL --retry 20 --retry-delay 10 -C - \
    -o "$VPC_TMP/vpc2024.tar.gz" "$VPC_ARCHIVE_URL"
  tar -xzf "$VPC_TMP/vpc2024.tar.gz" -C "$VPC_TMP"
  source_dir=$(find "$VPC_TMP" -mindepth 1 -maxdepth 1 -type d \
    -name 'Voice-Privacy-Challenge-2024-*' | head -1)
  test -n "$source_dir"
  if [[ -e "$VPC_DIR" ]]; then
    mv "$VPC_DIR" "$VPC_DIR.unpinned.$(date +%Y%m%d_%H%M%S)"
  fi
  mv "$source_dir" "$VPC_DIR"
  printf '%s\n' \
    7c80e86d3a4d58b81a2f3bdc01a3508c37018be4 \
    > "$VPC_DIR/.upstream_commit"
  log "DONE VPC repo commit"
else
  test "$(cat "$VPC_DIR/.upstream_commit")" = \
    7c80e86d3a4d58b81a2f3bdc01a3508c37018be4
  log "ALREADY_OK VPC repo commit"
fi

VPC_BASE="Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download"
download_small \
  "$(github_url "$VPC_BASE/data.zip/data.zip")" \
  "$DATA/vpc/data.zip" \
  60c71b3f2f8ff8d7a35237cda7d92fb2f6f5f1f2cb5c89cb91fc511a699860f7 \
  "VPC data.zip"
download_small \
  "$(github_url "$VPC_BASE/data.zip/data_test_tools.zip")" \
  "$DATA/vpc/data_test_tools.zip" \
  6270eba200a8986eee96b7e4ca9828be3000678073985c15273a5b34b3d4f304 \
  "VPC data_test_tools.zip"
download_small \
  "$(github_url "$VPC_BASE/pre_model.zip/asv_orig.zip")" \
  "$MODELS/vpc/asv_orig.zip" \
  f0abf60e569cb60a6f945a1a0a48e1a7d1aabe973f956dc3a872a3e686a7bf5e \
  "VPC asv_orig.zip"

ASR_ZIP="$MODELS/vpc/asr.zip"
ASR_SHA=28e9a67cb7319fedc61080f2d56e9bdf00f653d7ec665fc07c0db40ae66de106
if [[ -f "$ASR_ZIP" ]] && [[ "$(sha256_of "$ASR_ZIP")" == "$ASR_SHA" ]]; then
  log "ALREADY_OK VPC asr.zip"
else
  download_small \
    "$(github_url "$VPC_BASE/pre_model.zip/asr.zip")" \
    "$ASR_ZIP" \
    "$ASR_SHA" \
    "VPC asr.zip"
  log "DONE VPC asr.zip"
fi

unzip -t "$DATA/vpc/data.zip" >/dev/null
unzip -t "$DATA/vpc/data_test_tools.zip" >/dev/null
unzip -t "$MODELS/vpc/asv_orig.zip" >/dev/null
unzip -t "$MODELS/vpc/asr.zip" >/dev/null

source "$ROOT/hpc/activate_n019_official.sh"
unset HF_HUB_OFFLINE TRANSFORMERS_OFFLINE
export HF_ENDPOINT=https://hf-mirror.com

log "START HuBERT"
"$PYTHON" - <<'PY'
import os
from pathlib import Path
from huggingface_hub import snapshot_download

snapshot_download(
    repo_id="facebook/hubert-base-ls960",
    revision="dba3bb02fda4248b6e082697eee756de8fe8aa8a",
    local_dir=str(Path.home() / "voice_projects/models/n019_official/hubert"),
)
PY
log "DONE HuBERT"

log "START W-NT"
"$PYTHON" - <<'PY'
import os
from pathlib import Path
from huggingface_hub import snapshot_download

snapshot_download(
    repo_id="Orange/Speaker-wavLM-pro",
    revision="8451deb7b5019b9a99b1ed6a528dc75ba6b62b08",
    local_dir=str(Path.home() / "voice_projects/models/n019_official/wpro"),
    allow_patterns=[
        "README.md",
        "LICENSE.txt",
        "config.json",
        "spk_embeddings.py",
        "model.safetensors",
    ],
)
PY
test "$(stat -c '%s' "$MODELS/wpro/model.safetensors")" = "1266588504"
test "$(sha256_of "$MODELS/wpro/model.safetensors")" = \
  ad40a04ae6f0b46dbe6c7a6db71ff46f99775c59a0dccf61eb91f29216fbb2d4
log "DONE W-NT"

for repo in \
  "sarulab-speech/UTMOS22/archive/2d6d612cdf5bc610fde1a1b913c2d6c6fac8e063.tar.gz|UTMOS22" \
  "leto19/WhiSQA/archive/0ad007e97093aa54c0c8cdac1af3e6ad6305af3f.tar.gz|WhiSQA"; do
  path=${repo%%|*}
  name=${repo##*|}
  destination="$ROOT/vendor/$name"
  if [[ ! -d "$destination" ]]; then
    archive="$ROOT/vendor/$name.tar.gz"
    log "START $name"
    curl -fL --retry 20 --retry-delay 10 -C - \
      -o "$archive.part" "$(github_url "$path")"
    tar -tzf "$archive.part" >/dev/null
    mv "$archive.part" "$archive"
    mkdir -p "$destination"
    tar -xzf "$archive" -C "$destination" --strip-components=1
    log "DONE $name"
  else
    log "ALREADY_OK $name"
  fi
done

download_small \
  "https://media.githubusercontent.com/media/leto19/WhiSQA/0ad007e97093aa54c0c8cdac1af3e6ad6305af3f/checkpoints/single_head_model.pt" \
  "$MODELS/mos/WhiSQA_single_head.pt" \
  2da43d59294c358bdd3f450d0aef5ce57ad20bed3beb34657ef3a795a4766810 \
  "WhiSQA single_head_model.pt"

log "START UTMOS mirror"
"$PYTHON" - <<'PY'
import json
import os
from pathlib import Path
from huggingface_hub import HfApi, snapshot_download

repo_id = "mosmodels/utmos"
api = HfApi(endpoint=os.environ["HF_ENDPOINT"])
info = api.model_info(repo_id=repo_id)
local_dir = Path.home() / "voice_projects/models/n019_official/mos/UTMOS22-mirror"
snapshot_download(repo_id=repo_id, revision=info.sha, local_dir=str(local_dir))
audit = Path.home() / (
    "voice_projects/code/n019_official/audit/utmos_snapshot.json"
)
audit.write_text(
    json.dumps(
        {
            "repo_id": repo_id,
            "revision": info.sha,
            "local_dir": str(local_dir),
            "source_note": (
                "Mirror of sarulab-speech/UTMOS-demo. The author snapshot "
                "is not published by the paper."
            ),
        },
        indent=2,
        ensure_ascii=True,
    )
    + "\n",
    encoding="utf-8",
)
PY
log "DONE UTMOS mirror"

if [[ "$MODE" == "full" ]]; then
  download_parallel \
    "https://openslr.trmal.net/resources/12/dev-clean.tar.gz" \
    "$DATA/corpora/librispeech/dev-clean.tar.gz" \
    42e2234ba48799c1f50f24a7926300a1 \
    "LibriSpeech dev-clean"
  download_parallel \
    "https://openslr.trmal.net/resources/12/test-clean.tar.gz" \
    "$DATA/corpora/librispeech/test-clean.tar.gz" \
    32fa31d27d2e1cad72775fee3f4849a9 \
    "LibriSpeech test-clean"
  download_parallel \
    "https://openslr.trmal.net/resources/12/train-clean-100.tar.gz" \
    "$DATA/corpora/librispeech/train-clean-100.tar.gz" \
    2a93770f6d5c6c964bc36631d331a522 \
    "LibriSpeech train-clean-100"
  download_parallel \
    "https://openslr.trmal.net/resources/12/train-clean-360.tar.gz" \
    "$DATA/corpora/librispeech/train-clean-360.tar.gz" \
    c0e676e450a7ff2f54aeade5171606fa \
    "LibriSpeech train-clean-360"
  download_parallel \
    "https://openslr.trmal.net/resources/60/train-clean-100.tar.gz" \
    "$DATA/corpora/libritts/train-clean-100.tar.gz" \
    4a8c202b78fe1bc0c47916a98f3a2ea8 \
    "LibriTTS train-clean-100"
  download_parallel \
    "https://openslr.trmal.net/resources/60/train-other-500.tar.gz" \
    "$DATA/corpora/libritts/train-other-500.tar.gz" \
    7b181dd5ace343a5f38427999684aa6f \
    "LibriTTS train-other-500"
elif [[ "$MODE" != "eval" ]]; then
  echo "Unknown N019_ASSET_MODE: $MODE (expected eval or full)" >&2
  exit 2
fi

{
  echo "account=$ACCOUNT"
  echo "mode=$MODE"
  echo "date=$(date -Is)"
  sha256sum \
    "$DATA/vpc/data.zip" \
    "$DATA/vpc/data_test_tools.zip" \
    "$MODELS/vpc/asv_orig.zip" \
    "$MODELS/vpc/asr.zip" \
    "$MODELS/wpro/model.safetensors" \
    "$MODELS/mos/WhiSQA_single_head.pt"
  find "$DATA/corpora" -maxdepth 3 -type f -name '*.tar.gz' \
    -printf '%p %s\n' 2>/dev/null | sort
} > "$AUDIT/public_assets_$MODE.txt"

echo "PUBLIC_ASSETS_COMPLETE account=$ACCOUNT mode=$MODE"
