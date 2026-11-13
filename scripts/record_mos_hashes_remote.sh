#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
MODELS="$HOME/voice_projects/models/n019_official/mos"
WHISQA="$ROOT/vendor/WhiSQA/checkpoints/single_head_model.pt"

test "$(stat -c '%s' "$WHISQA")" = "364031990"
test "$(stat -c '%s' "$MODELS/UTMOS22-mirror/model.ckpt")" = "1238128841"
test "$(stat -c '%s' "$MODELS/UTMOS22-mirror/wav2vec_small.pt")" = "950500491"

{
  sha256sum \
    "$WHISQA" \
    "$MODELS/UTMOS22-mirror/model.ckpt" \
    "$MODELS/UTMOS22-mirror/wav2vec_small.pt"
  echo "UTMOS_revision=$("$HOME/voice_projects/envs/n019/bin/python" -c \
    'import json; print(json.load(open("'"$ROOT/audit/utmos_snapshot.json"'"))["revision"])')"
} > "$ROOT/audit/mos_assets.tsv"

cat "$ROOT/audit/mos_assets.tsv"
