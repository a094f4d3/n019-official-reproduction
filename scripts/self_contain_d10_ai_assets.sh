#!/bin/bash

set -euo pipefail

VOICE=/public/home/a094f4d10/voice_projects
SOURCE_VOICE=/public/home/a094f4d6/voice_projects
DATE=20261117

copy_replace_symlink() {
  local source="$1"
  local destination="$2"
  local label="$3"
  local staged="${destination}.local_${DATE}"

  test -e "$source" || {
    echo "Missing source for $label: $source" >&2
    return 1
  }
  test -L "$destination" || {
    echo "Expected symlink for $label: $destination" >&2
    return 1
  }
  test ! -e "$staged" || {
    echo "Staged destination already exists for $label: $staged" >&2
    return 1
  }

  echo "copying $label: $source -> $staged"
  cp -a "$source" "$staged"
  mv "$destination" "${destination}.symlink_${DATE}"
  mv "$staged" "$destination"
}

copy_replace_symlink \
  "$SOURCE_VOICE/code/n019_official/vendor" \
  "$VOICE/code/n019_official/vendor" \
  "vendor"

copy_replace_symlink \
  "$SOURCE_VOICE/models/n019_official/mos" \
  "$VOICE/models/n019_official/mos" \
  "mos"

copy_replace_symlink \
  "$SOURCE_VOICE/hf_cache/n019_official/hub" \
  "$VOICE/hf_cache/n019_official/hub" \
  "huggingface_hub"

copy_replace_symlink \
  "$SOURCE_VOICE/models/n019_official/wpro" \
  "$VOICE/models/n019_official/wpro" \
  "wpro"

echo "N019_D10_AI_ASSETS_SELF_CONTAINED"
