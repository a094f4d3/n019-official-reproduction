#!/usr/bin/env bash

set -u

LOGS="$HOME/voice_projects/logs/n019_official"
URL_PATH="resources/12/train-clean-360.tar.gz"
URLS=(
  "https://www.openslr.org/$URL_PATH"
  "https://openslr.trmal.net/$URL_PATH"
  "https://openslr.elda.org/$URL_PATH"
  "https://repo.openslr.org/$URL_PATH"
)

pid=""
if [[ -f "$LOGS/openslr_download.pid" ]]; then
  pid=$(cat "$LOGS/openslr_download.pid")
  kill -STOP "$pid" 2>/dev/null || true
fi

echo "aria2c=$(command -v aria2c || true)"
for url in "${URLS[@]}"; do
  echo "---$url"
  curl -L -sS --range 0-5000000 -o /dev/null --max-time 12 \
    -w 'http=%{http_code} bytes=%{size_download} speed_Bps=%{speed_download}\n' \
    "$url" || true
done

if [[ -n "$pid" ]]; then
  kill -CONT "$pid" 2>/dev/null || true
fi
