#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SRC="$N019_OFFICIAL_MODELS/vpc/exp/asr"
DST="${N019_VPC_ASR_LOCAL:-$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local}"
REV=54074b1c16f4de6a5ad59affb4caa8f2ea03a119
SNAPSHOT="$HF_HOME/hub/models--facebook--wav2vec2-large-960h-lv60-self/snapshots/$REV"

for required in \
  "$SRC/asr.ckpt" \
  "$SRC/tokenizer.ckpt" \
  "$SRC/wav2vec2.ckpt" \
  "$SRC/hyperparams.yaml" \
  "$SNAPSHOT/config.json" \
  "$SNAPSHOT/preprocessor_config.json"; do
  test -f "$required" || {
    echo "Missing local ASR model input: $required" >&2
    exit 1
  }
done

mkdir -p "$DST"
for filename in asr.ckpt tokenizer.ckpt wav2vec2.ckpt; do
  if [[ ! -e "$DST/$filename" ]]; then
    ln "$SRC/$filename" "$DST/$filename"
  fi
  cmp -s "$SRC/$filename" "$DST/$filename" || {
    echo "Hard-linked checkpoint mismatch: $filename" >&2
    exit 1
  }
done
cp "$SNAPSHOT/config.json" "$DST/config.json"
cp "$SNAPSHOT/preprocessor_config.json" "$DST/preprocessor_config.json"

python - "$SRC/hyperparams.yaml" "$DST/hyperparams.yaml" "$DST" <<'PY'
import sys
from pathlib import Path

source, output, model_dir = map(Path, sys.argv[1:])
lines = source.read_text(encoding="utf-8").splitlines()
updated = []
replaced = 0
for line in lines:
    if line.startswith("wav2vec2_hub:"):
        updated.append(f"wav2vec2_hub: {model_dir.resolve()}")
        replaced += 1
    else:
        updated.append(line)
if replaced != 1:
    raise SystemExit(f"Expected one wav2vec2_hub line, found {replaced}")
output.write_text("\n".join(updated) + "\n", encoding="utf-8")
print(f"ASR_LOCAL_HF_READY src={source} dst={output}")
PY

python - "$DST" <<'PY'
import sys
from pathlib import Path

from transformers import Wav2Vec2Config, Wav2Vec2FeatureExtractor

model_dir = Path(sys.argv[1])
feature_extractor = Wav2Vec2FeatureExtractor.from_pretrained(model_dir)
config = Wav2Vec2Config.from_pretrained(model_dir)
if feature_extractor.sampling_rate != 16_000:
    raise SystemExit("Unexpected Wav2Vec2 sample rate")
if config.hidden_size != 1024:
    raise SystemExit("Unexpected Wav2Vec2 hidden size")
print(
    "ASR_LOCAL_HF_PROBE_OK "
    f"sample_rate={feature_extractor.sampling_rate} "
    f"hidden_size={config.hidden_size}"
)
PY
sha256sum \
  "$SRC/asr.ckpt" "$DST/asr.ckpt" \
  "$SRC/tokenizer.ckpt" "$DST/tokenizer.ckpt" \
  "$SRC/wav2vec2.ckpt" "$DST/wav2vec2.ckpt" \
  "$DST/config.json" "$DST/preprocessor_config.json" "$DST/hyperparams.yaml"
echo "ASR_MODEL_LOCAL_HF_COMPLETE dst=$DST"
