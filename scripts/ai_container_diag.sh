#!/usr/bin/env bash

set -u
set -x

ROOT=/public/home/a094f4d4/voice_projects/code/n019_official

id
hostname
pwd
printf 'HOME=%s\n' "${HOME:-}"
ls -ld "$ROOT" "$ROOT/scripts" "$ROOT/hpc"
ls -l "$ROOT/scripts/run_ls360_target_embedding_pilot_ai.sh"
command -v bash
command -v python
command -v hy-smi || true
hy-smi || true

echo "N019_AI_CONTAINER_DIAG_COMPLETE"
