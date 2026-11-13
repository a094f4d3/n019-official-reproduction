#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
PYTHON="$HOME/voice_projects/envs/n019/bin/python"
PROXY="${N019_GITHUB_PROXY:-https://ghproxy.net/}"
CONNECTIONS="${N019_DOWNLOAD_CONNECTIONS:-16}"
RETRIES="${N019_DOWNLOAD_RETRIES:-50}"

if [[ -z "${SSL_CERT_FILE:-}" && -f /etc/pki/tls/certs/ca-bundle.crt ]]; then
  export SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt
fi

mkdir -p "$DATA/vpc" "$MODELS/vpc"
test -x "$PYTHON"

github_url() {
  printf '%shttps://github.com/%s\n' "$PROXY" "$1"
}

parallel_fetch() {
  local path=$1
  local output=$2
  local expected_sha=$3
  local label=$4

  if [[ -f "$output" ]]; then
    actual_sha=$(sha256sum "$output" | awk '{print $1}')
    if [[ "$actual_sha" == "$expected_sha" ]]; then
      echo "ALREADY_OK $label"
      return 0
    fi
    mv "$output" "$output.invalid.$(date +%Y%m%d_%H%M%S)"
  fi
  if [[ -e "$output.part" ]]; then
    mv "$output.part" "$output.part.previous.$(date +%Y%m%d_%H%M%S)"
  fi

  echo "START $label"
  "$PYTHON" "$ROOT/scripts/parallel_download_openslr.py" \
    --url "$(github_url "$path")" \
    --output "$output" \
    --expected-sha256 "$expected_sha" \
    --connections "$CONNECTIONS" \
    --retries "$RETRIES"
  echo "DONE $label"
}

VPC_BASE="Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download"
parallel_fetch \
  "$VPC_BASE/data.zip/data.zip" \
  "$DATA/vpc/data.zip" \
  60c71b3f2f8ff8d7a35237cda7d92fb2f6f5f1f2cb5c89cb91fc511a699860f7 \
  "VPC data.zip"
parallel_fetch \
  "$VPC_BASE/data.zip/data_test_tools.zip" \
  "$DATA/vpc/data_test_tools.zip" \
  6270eba200a8986eee96b7e4ca9828be3000678073985c15273a5b34b3d4f304 \
  "VPC data_test_tools.zip"
parallel_fetch \
  "$VPC_BASE/pre_model.zip/asv_orig.zip" \
  "$MODELS/vpc/asv_orig.zip" \
  f0abf60e569cb60a6f945a1a0a48e1a7d1aabe973f956dc3a872a3e686a7bf5e \
  "VPC asv_orig.zip"
parallel_fetch \
  "$VPC_BASE/pre_model.zip/asr.zip" \
  "$MODELS/vpc/asr.zip" \
  28e9a67cb7319fedc61080f2d56e9bdf00f653d7ec665fc07c0db40ae66de106 \
  "VPC asr.zip"

unzip -t "$DATA/vpc/data.zip" >/dev/null
unzip -t "$DATA/vpc/data_test_tools.zip" >/dev/null
unzip -t "$MODELS/vpc/asv_orig.zip" >/dev/null
unzip -t "$MODELS/vpc/asr.zip" >/dev/null
echo "VPC_RELEASE_PARALLEL_COMPLETE"
