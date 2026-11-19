#!/usr/bin/env bash

set -euo pipefail

ROOT="${1:?usage: corpus_wav_stats.sh ROOT}"
find "$ROOT" -type f -name '*.wav' -printf '%s\n' | awk '
  {bytes += $1; files += 1}
  END {printf "wav_files=%d wav_bytes=%d\n", files, bytes}
'
