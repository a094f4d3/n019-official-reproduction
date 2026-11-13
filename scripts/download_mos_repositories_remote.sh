#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
VENDOR="$ROOT/vendor"
AUDIT="$ROOT/audit"
mkdir -p "$VENDOR" "$AUDIT"

download_archive() {
  local url=$1
  local archive=$2
  local destination=$3
  local label=$4

  if [[ -d "$destination" ]]; then
    echo "ALREADY_PRESENT $label $destination"
    return 0
  fi

  echo "START $label"
  curl -L --fail --retry 10 --retry-delay 5 -C - -o "$archive.part" "$url"
  tar -tzf "$archive.part" >/dev/null
  mv "$archive.part" "$archive"
  mkdir -p "$destination"
  tar -xzf "$archive" -C "$destination" --strip-components=1
  echo "DONE $label"
}

download_archive \
  "https://ghproxy.net/https://github.com/sarulab-speech/UTMOS22/archive/2d6d612cdf5bc610fde1a1b913c2d6c6fac8e063.tar.gz" \
  "$VENDOR/UTMOS22-2d6d612.tar.gz" \
  "$VENDOR/UTMOS22" \
  "UTMOS22"

download_archive \
  "https://ghproxy.net/https://github.com/leto19/WhiSQA/archive/0ad007e97093aa54c0c8cdac1af3e6ad6305af3f.tar.gz" \
  "$VENDOR/WhiSQA-0ad007e.tar.gz" \
  "$VENDOR/WhiSQA" \
  "WhiSQA"

cat > "$AUDIT/mos_repository_commits.txt" <<'EOF'
UTMOS22 2d6d612cdf5bc610fde1a1b913c2d6c6fac8e063
WhiSQA 0ad007e97093aa54c0c8cdac1af3e6ad6305af3f
EOF

echo "MOS_REPOSITORIES_COMPLETE"
