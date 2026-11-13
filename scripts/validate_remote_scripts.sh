#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
PYTHON="$HOME/voice_projects/envs/n019/bin/python"

while IFS= read -r -d '' script; do
  bash -n "$script"
done < <(find "$ROOT/scripts" -maxdepth 1 -type f -name '*.sh' -print0)

"$PYTHON" -m py_compile "$ROOT/scripts/"*.py

echo "SCRIPTS_VALIDATED"
