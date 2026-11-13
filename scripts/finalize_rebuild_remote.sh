#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"

source "$ROOT/hpc/activate_n019_official.sh"

python "$ROOT/scripts/verify_vpc_rebuild.py" \
  --vpc-root "$DATA/vpc" \
  --output "$ROOT/audit/materialize_full/verification.json"

bash "$ROOT/scripts/package_rebuilt_remote.sh"
