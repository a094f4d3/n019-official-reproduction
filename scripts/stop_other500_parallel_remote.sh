#!/usr/bin/env bash

set -u

echo "host=$(hostname)"
pkill -TERM -f "[e]xtract_other500_parallel_tar_remote.sh" 2>/dev/null || true
pkill -TERM -f "[p]igz -dc -p 16 .*train-other-500" 2>/dev/null || true
pkill -TERM -f "[p]arallel_extract_tar.py" 2>/dev/null || true
sleep 2

pgrep -af "[e]xtract_other500_parallel_tar_remote.sh" || true
pgrep -af "[p]igz -dc -p 16 .*train-other-500" || true
pgrep -af "[p]arallel_extract_tar.py" || true
