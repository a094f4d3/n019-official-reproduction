#!/usr/bin/env bash

set -u

echo "host=$(hostname)"
pkill -TERM -f "[e]xtract_other500_stream_remote.sh" 2>/dev/null || true
pkill -TERM -f "[m]d5sum .*train-other-500.tar.gz" 2>/dev/null || true
pkill -TERM -f "[s]tream_extract_tar.py" 2>/dev/null || true
pkill -TERM -f "[p]igz -dc -p 24 .*train-other-500.tar.gz" 2>/dev/null || true
sleep 2

pgrep -af "[e]xtract_other500_stream_remote.sh" || true
pgrep -af "[s]tream_extract_tar.py" || true
