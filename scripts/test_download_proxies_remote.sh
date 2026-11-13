#!/usr/bin/env bash

set -u

LOGS="$HOME/voice_projects/logs/n019_official"
ASR_PID_FILE="$LOGS/asr_download.pid"
OPENSLR_PID_FILE="$LOGS/openslr_download.pid"

if [[ -f "$ASR_PID_FILE" ]]; then
  asr_pid=$(cat "$ASR_PID_FILE")
  pkill -TERM -P "$asr_pid" 2>/dev/null || true
  kill -TERM "$asr_pid" 2>/dev/null || true
fi

if [[ -f "$OPENSLR_PID_FILE" ]]; then
  openslr_pid=$(cat "$OPENSLR_PID_FILE")
  kill -STOP "$openslr_pid" 2>/dev/null || true
fi

urls=(
  "https://ghfast.top/https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download/pre_model.zip/asr.zip"
  "https://gh-proxy.com/https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download/pre_model.zip/asr.zip"
  "https://ghproxy.net/https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download/pre_model.zip/asr.zip"
  "https://github.moeyy.xyz/https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download/pre_model.zip/asr.zip"
  "https://gh.llkk.cc/https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download/pre_model.zip/asr.zip"
)

for url in "${urls[@]}"; do
  echo "--- $url"
  curl -L -sS -o /dev/null --max-time 15 \
    -w 'http=%{http_code} bytes=%{size_download} speed_Bps=%{speed_download}\n' \
    "$url" || true
done

if [[ -f "$OPENSLR_PID_FILE" ]]; then
  openslr_pid=$(cat "$OPENSLR_PID_FILE")
  kill -CONT "$openslr_pid" 2>/dev/null || true
fi
