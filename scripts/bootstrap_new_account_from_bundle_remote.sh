#!/usr/bin/env bash

set -euo pipefail

ACCOUNT="$(id -un)"
case "$ACCOUNT" in
  a094f4d6|a094f4d7) ;;
  *)
    echo "This bootstrap is restricted to a094f4d6/a094f4d7: $ACCOUNT" >&2
    exit 2
    ;;
esac

ROOT="$HOME/voice_projects/code/n019_official"
BASE_ENV="$HOME/voice_projects/miniconda3/envs/py311"
BUNDLE_DIR="$HOME/voice_projects/tmp"
ENV_ARCHIVE="${N019_ENV_ARCHIVE:-$BUNDLE_DIR/py311_conda_unpack_20261103.tar.zst}"
CODE_ARCHIVE="${N019_CODE_ARCHIVE:-$BUNDLE_DIR/n019_code_20261104_r24.tar.gz}"
ENV_SHA256="${N019_ENV_ARCHIVE_SHA256:-}"
CODE_SHA256="${N019_CODE_ARCHIVE_SHA256:-}"
STAMP="$(date +%Y%m%d_%H%M%S)"

for path in "$ENV_ARCHIVE" "$CODE_ARCHIVE"; do
  if [[ ! -s "$path" ]]; then
    echo "Missing bundle file: $path" >&2
    exit 3
  fi
done

check_sha256() {
  local path="$1"
  local expected="$2"
  if [[ -z "$expected" ]]; then
    return
  fi
  local actual
  actual="$(sha256sum "$path" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "SHA256 mismatch for $path: expected=$expected actual=$actual" >&2
    exit 4
  fi
  echo "sha256_ok file=$path hash=$actual"
}

check_sha256 "$ENV_ARCHIVE" "$ENV_SHA256"
check_sha256 "$CODE_ARCHIVE" "$CODE_SHA256"

mkdir -p \
  "$HOME/voice_projects/miniconda3/envs" \
  "$HOME/voice_projects/code" \
  "$HOME/voice_projects/data/n019_official" \
  "$HOME/voice_projects/models/n019_official" \
  "$HOME/voice_projects/logs/n019_official" \
  "$HOME/voice_projects/runs/n019_official"

if [[ ! -x "$BASE_ENV/bin/python" ]]; then
  STAGE="$(mktemp -d "$HOME/voice_projects/miniconda3/envs/.py311-extract.XXXXXX")"
  echo "extracting_env archive=$ENV_ARCHIVE stage=$STAGE"
  tar -I zstd -xf "$ENV_ARCHIVE" -C "$STAGE"
  if [[ ! -x "$STAGE/py311/bin/python" ]]; then
    echo "Archive did not contain py311/bin/python" >&2
    exit 5
  fi
  mv "$STAGE/py311" "$BASE_ENV"
fi

if [[ ! -x "$BASE_ENV/bin/python" ]]; then
  echo "Missing base env after extraction: $BASE_ENV/bin/python" >&2
  exit 6
fi

if [[ -x "$BASE_ENV/bin/conda-unpack" ]]; then
  "$BASE_ENV/bin/python" "$BASE_ENV/bin/conda-unpack"
  echo "conda_unpack_ok prefix=$BASE_ENV"
fi
"$BASE_ENV/bin/python" --version

if [[ ! -f "$ROOT/hpc/activate_n019_official.sh" ]]; then
  CODE_STAGE="$(mktemp -d "$HOME/voice_projects/code/.n019-code-extract.XXXXXX")"
  echo "extracting_code archive=$CODE_ARCHIVE stage=$CODE_STAGE"
  tar -xzf "$CODE_ARCHIVE" -C "$CODE_STAGE"
  if [[ ! -f "$CODE_STAGE/hpc/activate_n019_official.sh" ]]; then
    echo "Archive did not contain hpc/activate_n019_official.sh" >&2
    exit 7
  fi
  mv "$CODE_STAGE" "$ROOT"
fi

cd "$ROOT"
bash scripts/multi_account/provision_account_remote.sh
bash scripts/multi_account/audit_account_remote.sh
bash scripts/run_unit_tests_remote.sh

echo "NEW_ACCOUNT_BOOTSTRAP_COMPLETE account=$ACCOUNT stamp=$STAMP"
