#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
MODELS="$HOME/voice_projects/models/n019_official/mos"
AUDIT="$ROOT/audit"
PYTHON="$HOME/voice_projects/envs/n019/bin/python"
mkdir -p "$MODELS" "$AUDIT"

WHISQA="$ROOT/vendor/WhiSQA/checkpoints/single_head_model.pt"
EXPECTED_SIZE=364031990
EXPECTED_SHA="2da43d59294c358bdd3f450d0aef5ce57ad20bed3beb34657ef3a795a4766810"
URL="https://media.githubusercontent.com/media/leto19/WhiSQA/0ad007e97093aa54c0c8cdac1af3e6ad6305af3f/checkpoints/single_head_model.pt"

if [[ -f "$WHISQA" ]] \
  && [[ "$(stat -c '%s' "$WHISQA")" != "$EXPECTED_SIZE" ]]; then
  mv "$WHISQA" "$WHISQA.lfs-pointer.$(date +%Y%m%d_%H%M%S)"
fi

echo "[$(date -Is)] START WhiSQA checkpoint"
"$PYTHON" "$ROOT/scripts/parallel_download_openslr.py" \
  --url "$URL" \
  --output "$WHISQA" \
  --expected-sha256 "$EXPECTED_SHA" \
  --connections 12

test "$(stat -c '%s' "$WHISQA")" = "$EXPECTED_SIZE"
actual_sha=$(sha256sum "$WHISQA" | awk '{print $1}')
test "$actual_sha" = "$EXPECTED_SHA"
echo "[$(date -Is)] WHISQA_OK $actual_sha"

source "$ROOT/hpc/activate_n019_official.sh"
unset HF_HUB_OFFLINE TRANSFORMERS_OFFLINE
export HF_ENDPOINT="https://hf-mirror.com"

python - <<'PY'
import json
import os
from pathlib import Path

from huggingface_hub import HfApi, snapshot_download

repo_id = "mosmodels/utmos"
local_dir = Path(os.environ["HOME"]) / (
    "voice_projects/models/n019_official/mos/UTMOS22-mirror"
)
audit_path = Path(os.environ["HOME"]) / (
    "voice_projects/code/n019_official/audit/utmos_snapshot.json"
)

api = HfApi(endpoint=os.environ["HF_ENDPOINT"])
info = api.model_info(repo_id=repo_id)
snapshot_download(
    repo_id=repo_id,
    revision=info.sha,
    local_dir=str(local_dir),
)
audit = {
    "repo_id": repo_id,
    "repo_type": "model",
    "revision": info.sha,
    "local_dir": str(local_dir),
    "source_note": (
        "Unofficial mirror of sarulab-speech/UTMOS-demo, as stated in "
        "the mirror model card. The exact author snapshot is unpublished."
    ),
}
audit_path.write_text(
    json.dumps(audit, indent=2, ensure_ascii=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(audit, indent=2))
PY

sha256sum "$WHISQA" > "$MODELS/WhiSQA_single_head.sha256"
echo "MOS_CHECKPOINTS_COMPLETE"
