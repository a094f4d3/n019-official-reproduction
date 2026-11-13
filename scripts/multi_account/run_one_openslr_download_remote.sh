#!/usr/bin/env bash

set -u

ROOT="$HOME/voice_projects/code/n019_official"
PYTHON="$HOME/voice_projects/envs/n019/bin/python"
CONNECTIONS=${N019_DOWNLOAD_CONNECTIONS:-16}
if [[ -z "${SSL_CERT_FILE:-}" && -f /etc/pki/tls/certs/ca-bundle.crt ]]; then
  export SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt
fi

label=$1
url=$2
output=$3
expected_md5=$4

while true; do
  echo "[$(date -Is)] START $label connections=$CONNECTIONS"
  if "$PYTHON" "$ROOT/scripts/parallel_download_openslr.py" \
    --url "$url" \
    --output "$output" \
    --expected-md5 "$expected_md5" \
    --connections "$CONNECTIONS"; then
    echo "[$(date -Is)] DONE $label"
    exit 0
  fi
  echo "[$(date -Is)] RETRY $label in 60s"
  sleep 60
done
