#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
LOGS="$HOME/voice_projects/logs/n019_official"
mkdir -p "$LOGS"

nohup bash "$ROOT/scripts/verify_asset_hashes_remote.sh" \
  > "$LOGS/verify_assets.log" 2>&1 &
echo $! > "$LOGS/verify_assets.pid"
echo "verify_assets_pid=$(cat "$LOGS/verify_assets.pid")"
