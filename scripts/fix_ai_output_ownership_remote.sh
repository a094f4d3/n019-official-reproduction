#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh" >/dev/null

if [[ "$(id -u)" != "0" ]]; then
  echo "This maintenance script must run as root inside an AI container." >&2
  exit 2
fi

if [[ "$#" -eq 0 ]]; then
  set -- \
    "$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_360_target_nt_utterance_shards"
fi

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
if [[ "$owner" == "0:0" ]]; then
  echo "Refusing to chown project output to root: $N019_OFFICIAL_DATA" >&2
  exit 3
fi

for target in "$@"; do
  if [[ ! -e "$target" ]]; then
    echo "missing target=$target"
    continue
  fi
  case "$target" in
    "$N019_OFFICIAL_DATA"/*|"$N019_OFFICIAL_RUNS"/*) ;;
    *)
      echo "Refusing path outside N019_OFFICIAL_DATA or N019_OFFICIAL_RUNS: $target" >&2
      exit 4
      ;;
  esac
  chown -R "$owner" "$target"
  echo "owner=$owner target=$target"
done

echo "OWNERSHIP_FIX_COMPLETE"
