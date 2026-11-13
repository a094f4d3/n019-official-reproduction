#!/usr/bin/env bash

set -u

echo "host=$(hostname)"
pkill -TERM -f "[r]eextract_other500_pigz_remote.sh" 2>/dev/null || true
pkill -TERM -f "[p]igz -dc -p 16 .*train-other-500.tar.gz" 2>/dev/null || true
pkill -TERM -f "[t]ar -xf - -C" 2>/dev/null || true
sleep 2

pgrep -af "[r]eextract_other500_pigz_remote.sh" || true
pgrep -af "[p]igz -dc -p 16" || true
