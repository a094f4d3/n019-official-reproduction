#!/usr/bin/env bash

set -euo pipefail

DATA="$HOME/voice_projects/data/n019_official/corpora"
LOGS="$HOME/voice_projects/logs/n019_official"
ROOT="$HOME/voice_projects/code/n019_official"

mkdir -p "$DATA/librispeech" "$DATA/libritts" "$LOGS"

if pgrep -f '[r]un_one_openslr_download_remote.sh' >/dev/null 2>&1; then
  echo "OpenSLR workers already running; refusing to start duplicates."
  exit 0
fi

nohup setsid "$ROOT/scripts/multi_account/run_one_openslr_download_remote.sh" \
"LibriSpeech train-clean-100" \
"https://openslr.trmal.net/resources/12/train-clean-100.tar.gz" \
"$DATA/librispeech/train-clean-100.tar.gz" \
"2a93770f6d5c6c964bc36631d331a522" \
> "$LOGS/openslr_train_clean_100.log" 2>&1 < /dev/null &

nohup setsid "$ROOT/scripts/multi_account/run_one_openslr_download_remote.sh" \
"LibriSpeech train-clean-360" \
"https://openslr.trmal.net/resources/12/train-clean-360.tar.gz" \
"$DATA/librispeech/train-clean-360.tar.gz" \
"c0e676e450a7ff2f54aeade5171606fa" \
> "$LOGS/openslr_train_clean_360.log" 2>&1 < /dev/null &

nohup setsid "$ROOT/scripts/multi_account/run_one_openslr_download_remote.sh" \
"LibriTTS train-clean-100" \
"https://openslr.trmal.net/resources/60/train-clean-100.tar.gz" \
"$DATA/libritts/train-clean-100.tar.gz" \
"4a8c202b78fe1bc0c47916a98f3a2ea8" \
> "$LOGS/openslr_libritts_clean_100.log" 2>&1 < /dev/null &

nohup setsid "$ROOT/scripts/multi_account/run_one_openslr_download_remote.sh" \
"LibriTTS train-other-500" \
"https://openslr.trmal.net/resources/60/train-other-500.tar.gz" \
"$DATA/libritts/train-other-500.tar.gz" \
"7b181dd5ace343a5f38427999684aa6f" \
> "$LOGS/openslr_libritts_other_500.log" 2>&1 < /dev/null &

sleep 2
for pid in $(pgrep -f 'run_one_openslr_download_remote.sh' || true); do
  echo "worker_pid=$pid"
done

echo "OPENSLR_WORKERS_STARTED"
