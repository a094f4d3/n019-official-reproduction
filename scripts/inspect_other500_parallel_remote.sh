#!/usr/bin/env bash

set -u

echo "host=$(hostname) date=$(date -Is)"
pgrep -af "[e]xtract_other500_parallel_tar_remote.sh" || true
pgrep -af "[p]igz -dc -p 16 .*train-other-500" || true
pgrep -af "[p]arallel_extract_tar.py" || true
find /dev/shm -maxdepth 1 -name 'n019_a094f4d4_train-other-500*' \
  -printf '%p %s\n' 2>/dev/null || true
stat -c 'log_mtime=%y log_bytes=%s' \
  "$HOME/voice_projects/logs/n019_official/other500_parallel.log"
