#!/usr/bin/env bash

set -u

echo "host=$(hostname)"
pkill -TERM -f "[e]xtract_training_corpora_remote.sh" 2>/dev/null || true
pkill -TERM -f "[t]ar -xzf .*train-other-500.tar.gz" 2>/dev/null || true
sleep 2

pgrep -af "[e]xtract_training_corpora_remote.sh" || true
pgrep -af "[t]ar -xzf .*train-other-500.tar.gz" || true
