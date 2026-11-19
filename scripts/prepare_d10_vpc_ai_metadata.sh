#!/bin/bash

set -euo pipefail

DEST=/public/home/a094f4d10/voice_projects/data/n019_official/vpc_ai/data
SOURCE=/public/home/a094f4d6/voice_projects/data/n019_official/vpc/data

test -d "$SOURCE/libri_test"
test -d "$SOURCE/libri_test_enrolls"
test -d "$SOURCE/libri_test_trials_f"
test -d "$SOURCE/libri_test_trials_m"
mkdir -p \
  "$DEST/libri_test" \
  "$DEST/libri_test_enrolls" \
  "$DEST/libri_test_trials_f" \
  "$DEST/libri_test_trials_m"

tar -C "$SOURCE/libri_test" --exclude=wav -cf - . |
  tar -C "$DEST/libri_test" -xf -
tar -C "$SOURCE/libri_test_enrolls" -cf - . |
  tar -C "$DEST/libri_test_enrolls" -xf -
tar -C "$SOURCE/libri_test_trials_f" -cf - . |
  tar -C "$DEST/libri_test_trials_f" -xf -
tar -C "$SOURCE/libri_test_trials_m" -cf - . |
  tar -C "$DEST/libri_test_trials_m" -xf -

test "$(wc -l < "$DEST/libri_test/wav.scp")" = 1934
test "$(wc -l < "$DEST/libri_test_enrolls/wav.scp")" = 438
test "$(wc -l < "$DEST/libri_test_trials_f/trials")" = 11744
test "$(wc -l < "$DEST/libri_test_trials_m/trials")" = 9906
echo "N019_D10_VPC_AI_METADATA_COMPLETE dest=$DEST"
