#!/bin/bash

set -euo pipefail

ASR=/public/home/a094f4d10/voice_projects/models/n019_official/vpc_asr_local/asr_n019_local
YAML="$ASR/hyperparams.yaml"
LOCAL_SOURCE="/public/home/a094f4d10/voice_projects/models/n019_official/vpc_asr_local/asr_n019_local"

test -s "$YAML"
test -s "$ASR/config.json"
test -s "$ASR/preprocessor_config.json"
test -s "$ASR/wav2vec2.ckpt"

export TMPDIR=/public/home/a094f4d10/voice_projects/tmp
mkdir -p "$TMPDIR"

if [[ ! -e "$YAML.bak_before_d10_local_source" ]]; then
  cp "$YAML" "$YAML.bak_before_d10_local_source"
fi

PYTHON=/public/home/a094f4d10/voice_projects/envs/n019/bin/python

"$PYTHON" - "$YAML" "$LOCAL_SOURCE" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
source = sys.argv[2]
text = path.read_text(encoding="utf-8")
updated, count = re.subn(
    r"(?m)^wav2vec2_hub: .+$",
    "wav2vec2_hub: {}".format(source),
    text,
)
if count != 1:
    raise SystemExit("Expected one wav2vec2_hub line, replaced {}".format(count))
path.write_text(updated, encoding="utf-8")
print("ASR_HYPERPARAMS_UPDATED source={}".format(source))
PY

grep -F "wav2vec2_hub: $LOCAL_SOURCE" "$YAML"
