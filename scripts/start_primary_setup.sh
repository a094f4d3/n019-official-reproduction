#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

cd "$ROOT"
tar -xzf bootstrap_assets.tar.gz -C "$ROOT"
tar -xzf scripts_remote.tar.gz -C "$ROOT"
chmod +x "$ROOT/scripts/"*.sh

if [[ ! -f "$ROOT/audit/bootstrap_zip_sha256.txt" ]]; then
  "$ROOT/scripts/bootstrap_remote_assets.sh"
fi

if [[ ! -f "$LOGS/asr_download.pid" ]] \
  || ! kill -0 "$(cat "$LOGS/asr_download.pid")" 2>/dev/null; then
  nohup "$ROOT/scripts/download_vpc_assets_remote.sh" \
    > "$LOGS/asr_download.log" 2>&1 &
  echo $! > "$LOGS/asr_download.pid"
fi

if [[ ! -f "$LOGS/openslr_download.pid" ]] \
  || ! kill -0 "$(cat "$LOGS/openslr_download.pid")" 2>/dev/null; then
  nohup "$ROOT/scripts/download_openslr_remote.sh" \
    > "$LOGS/openslr_download.log" 2>&1 &
  echo $! > "$LOGS/openslr_download.pid"
fi

echo "SETUP_STARTED"
echo "asr_pid=$(cat "$LOGS/asr_download.pid")"
echo "openslr_pid=$(cat "$LOGS/openslr_download.pid")"
