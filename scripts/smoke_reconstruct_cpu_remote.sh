#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
export PYTHONPATH="$ROOT/src${PYTHONPATH:+:$PYTHONPATH}"

DATA="${N019_OFFICIAL_DATA:-$N019_VOICE_ROOT/data/n019_official}"
SPLIT="$DATA/processed/units/libritts_train_clean_100_speaker_split_seed20261102"
OUT="${N019_RECONSTRUCT_SMOKE_OUT:-$N019_VOICE_ROOT/tmp/vocoder_reconstruct_smoke_$(date +%Y%m%d_%H%M%S)}"
VOCODER="${N019_RECONSTRUCT_SMOKE_VOCODER:-$N019_OFFICIAL_RUNS/audit/vocoder_checkpoint_cpu_20261106/checkpoints/paperfix_ext_best_step102000.pt}"
DURATION="${N019_RECONSTRUCT_SMOKE_DURATION:-$N019_OFFICIAL_RUNS/duration_pred_paperfix/best.pt}"
EMBEDDINGS="$DATA/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz"

for required in \
  "$SPLIT/manifest_dev.jsonl" \
  "$SPLIT/unit_records_dev.jsonl" \
  "$VOCODER" \
  "$DURATION" \
  "$EMBEDDINGS"; do
  test -f "$required" || {
    echo "Missing reconstruction smoke input: $required" >&2
    exit 1
  }
done

python -u -m n019.reconstruct_vocoder \
  --source-manifest "$SPLIT/manifest_dev.jsonl" \
  --unit-records "$SPLIT/unit_records_dev.jsonl" \
  --vocoder "$VOCODER" \
  --vocoder-type nt \
  --vocoder-embeddings "$EMBEDDINGS" \
  --duration-mode pred \
  --duration-model "$DURATION" \
  --out-dir "$OUT" \
  --limit 1 \
  --device cpu

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path
import soundfile as sf

out = Path(sys.argv[1])
rows = [
    json.loads(line)
    for line in (out / "reconstructed.jsonl").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
if len(rows) != 1:
    raise SystemExit(f"Expected one reconstruction, got {len(rows)}")
info = sf.info(rows[0]["audio"])
if info.samplerate != 16000 or info.channels != 1 or info.frames <= 0:
    raise SystemExit(f"Bad reconstructed WAV: {info}")
meta = json.loads((out / "run_meta.json").read_text(encoding="utf-8"))
if meta["records"] != 1:
    raise SystemExit(f"Bad run_meta: {meta}")
print(json.dumps({"out": str(out), "wav": rows[0]["audio"], "frames": info.frames}, indent=2))
PY

find "$OUT" -maxdepth 1 -type f -print0 | sort -z | xargs -0 sha256sum
echo "N019_RECONSTRUCT_SMOKE_OK out=$OUT"
