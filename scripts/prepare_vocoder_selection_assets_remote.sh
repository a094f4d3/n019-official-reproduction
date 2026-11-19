#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

ACCOUNT="$(id -un)"
case "$ACCOUNT" in
  a094f4d3|a094f4d4|a094f4d5|a094f4d6|a094f4d7|a094f4d10) ;;
  *)
    echo "Refusing unexpected SCNet account: $ACCOUNT" >&2
    exit 2
    ;;
esac

MODELS="$N019_OFFICIAL_MODELS"
AUDIT="$ROOT/audit"
mkdir -p "$AUDIT" "$MODELS/mos" "$MODELS/vpc/exp"

WHISQA_CODE="$ROOT/vendor/WhiSQA"
WHISQA_CHECKPOINT="$MODELS/mos/WhiSQA_single_head.pt"
WHISQA_SHA=2da43d59294c358bdd3f450d0aef5ce57ad20bed3beb34657ef3a795a4766810
WHISQA_BYTES=364031990
WHISQA_URL="https://media.githubusercontent.com/media/leto19/WhiSQA/0ad007e97093aa54c0c8cdac1af3e6ad6305af3f/checkpoints/single_head_model.pt"

WHISPER_REV=973afd24965f72e36ca33b3055d56a652f456b4d
WHISPER_DIR="${N019_SELECTION_WHISPER_SMALL_DIR:-$MODELS/whisper-small/$WHISPER_REV}"
WAV2VEC_REV=54074b1c16f4de6a5ad59affb4caa8f2ea03a119
WAV2VEC_DIR="${N019_SELECTION_WAV2VEC_DIR:-$MODELS/wav2vec2-large-960h-lv60-self/$WAV2VEC_REV}"

test -d "$WHISQA_CODE" || {
  echo "Missing pinned WhiSQA code: $WHISQA_CODE" >&2
  exit 1
}

if [[ ! -f "$WHISQA_CHECKPOINT" ]] \
  || [[ "$(stat -c '%s' "$WHISQA_CHECKPOINT")" != "$WHISQA_BYTES" ]] \
  || [[ "$(sha256sum "$WHISQA_CHECKPOINT" | awk '{print $1}')" != "$WHISQA_SHA" ]]; then
  python "$ROOT/scripts/parallel_download_openslr.py" \
    --url "$WHISQA_URL" \
    --output "$WHISQA_CHECKPOINT" \
    --expected-sha256 "$WHISQA_SHA" \
    --connections "${N019_DOWNLOAD_CONNECTIONS:-12}"
fi
test "$(stat -c '%s' "$WHISQA_CHECKPOINT")" = "$WHISQA_BYTES"
test "$(sha256sum "$WHISQA_CHECKPOINT" | awk '{print $1}')" = "$WHISQA_SHA"

unset HF_HUB_OFFLINE TRANSFORMERS_OFFLINE
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

python - "$WHISPER_REV" "$WHISPER_DIR" "$WAV2VEC_REV" "$WAV2VEC_DIR" <<'PY'
import sys
from pathlib import Path

from huggingface_hub import snapshot_download

whisper_rev, whisper_dir, wav2vec_rev, wav2vec_dir = sys.argv[1:]
snapshot_download(
    repo_id="openai/whisper-small",
    revision=whisper_rev,
    local_dir=whisper_dir,
    allow_patterns=[
        "added_tokens.json",
        "config.json",
        "generation_config.json",
        "merges.txt",
        "model.safetensors",
        "normalizer.json",
        "preprocessor_config.json",
        "special_tokens_map.json",
        "tokenizer.json",
        "tokenizer_config.json",
        "vocab.json",
    ],
)
snapshot_download(
    repo_id="facebook/wav2vec2-large-960h-lv60-self",
    revision=wav2vec_rev,
    local_dir=wav2vec_dir,
    allow_patterns=["config.json", "preprocessor_config.json"],
)
print(f"WHISPER_DIR={whisper_dir}")
print(f"WAV2VEC_DIR={wav2vec_dir}")
PY

for required in \
  "$WHISPER_DIR/config.json" \
  "$WHISPER_DIR/model.safetensors" \
  "$WHISPER_DIR/tokenizer.json" \
  "$WAV2VEC_DIR/config.json" \
  "$WAV2VEC_DIR/preprocessor_config.json"; do
  test -f "$required" || {
    echo "Missing pinned selection asset: $required" >&2
    exit 1
  }
done

python - "$WHISPER_DIR/config.json" "$WAV2VEC_DIR/config.json" <<'PY'
import json
import sys
from pathlib import Path

whisper = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
wav2vec = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
if whisper.get("model_type") != "whisper":
    raise SystemExit("Unexpected Whisper config")
if wav2vec.get("model_type") != "wav2vec2":
    raise SystemExit("Unexpected Wav2Vec2 config")
print(
    "SELECTION_CONFIG_PROBE_OK "
    f"whisper_d_model={whisper.get('d_model')} "
    f"wav2vec_hidden={wav2vec.get('hidden_size')}"
)
PY

bash "$ROOT/scripts/prepare_asr_model_local_hf_remote.sh"

UTMOS_CHECKPOINT="$MODELS/mos/UTMOS22-mirror/model.ckpt"
test -f "$UTMOS_CHECKPOINT"

sha256sum \
  "$WHISQA_CHECKPOINT" \
  "$WHISPER_DIR/config.json" \
  "$WHISPER_DIR/model.safetensors" \
  "$WHISPER_DIR/tokenizer.json" \
  "$WAV2VEC_DIR/config.json" \
  "$WAV2VEC_DIR/preprocessor_config.json" \
  "$UTMOS_CHECKPOINT" \
  "$MODELS/vpc/exp/asr_n019_local/config.json" \
  "$MODELS/vpc/exp/asr_n019_local/preprocessor_config.json" \
  | tee "$AUDIT/vocoder_selection_assets_${ACCOUNT}.sha256"

echo "N019_VOCODER_SELECTION_ASSETS_READY account=$ACCOUNT"
