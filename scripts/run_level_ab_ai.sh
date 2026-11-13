#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:?Set N019_OFFICIAL_ROOT}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

OUT="${N019_LEVEL_OUT:?Set N019_LEVEL_OUT}"
ANON_JSONL="${N019_LEVEL_ANON_JSONL:?Set N019_LEVEL_ANON_JSONL}"
LIMIT="${N019_LEVEL_LIMIT:-120}"
GAIN_DB="${N019_LEVEL_GAIN_DB:--4.2}"

UTMOS_CODE="$ROOT/vendor/UTMOS22-demo"
UTMOS_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt"
WHISQA_CODE="$ROOT/vendor/WhiSQA"
WHISQA_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"
WHISPER_SMALL_PATH="${N019_LEVEL_WHISPER_SMALL_PATH:-$N019_VOICE_ROOT/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d}"

export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"
export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"

mkdir -p "$OUT/raw" "$OUT/gain"

python - "$ANON_JSONL" "$OUT" "$LIMIT" "$GAIN_DB" <<'PY'
import json
import math
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

anon_jsonl, out_root, limit, gain_db = (
    Path(sys.argv[1]),
    Path(sys.argv[2]),
    int(sys.argv[3]),
    float(sys.argv[4]),
)

rows = []
with anon_jsonl.open(encoding="utf-8") as handle:
    for line in handle:
        if line.strip():
            rows.append(json.loads(line))
        if len(rows) >= limit:
            break

gain = 10.0 ** (gain_db / 20.0)
raw_entries = []
gain_entries = []
for row in rows:
    utt = row["utterance_id"]
    source = Path(row["audio"])
    audio, sample_rate = sf.read(str(source), dtype="float32", always_2d=True)
    mono = audio.mean(axis=1)
    scaled = np.clip(mono * gain, -1.0, 1.0)
    target = out_root / "gain" / f"{utt}.wav"
    sf.write(str(target), scaled, sample_rate, subtype="PCM_16")
    raw_entries.append(f"{utt} {source}")
    gain_entries.append(f"{utt} {target}")

(out_root / "raw" / "wav.scp").write_text("\n".join(raw_entries) + "\n", encoding="utf-8")
(out_root / "gain" / "wav.scp").write_text("\n".join(gain_entries) + "\n", encoding="utf-8")
print(f"level_ab_rows={len(rows)} gain_db={gain_db}")
PY

for condition in raw gain; do
  python -u -m n019.eval_mos \
    --backend utmos \
    --wav-scp "$OUT/$condition/wav.scp" \
    --code-source "$UTMOS_CODE" \
    --checkpoint "$UTMOS_CHECKPOINT" \
    --device cuda \
    --out "$OUT/$condition/UTMOS.json"
  python -u -m n019.eval_mos \
    --backend whisqa \
    --wav-scp "$OUT/$condition/wav.scp" \
    --code-source "$WHISQA_CODE" \
    --checkpoint "$WHISQA_CHECKPOINT" \
    --device cuda \
    --out "$OUT/$condition/WhiSQA.json"
done

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
report = {"conditions": {}}
for condition in ("raw", "gain"):
    entry = {}
    for metric in ("UTMOS", "WhiSQA"):
        data = json.loads((out / condition / f"{metric}.json").read_text(encoding="utf-8"))
        entry[metric] = {
            "count": data["count"],
            "mean": data["mean"],
            "stddev": data["stddev"],
        }
    report["conditions"][condition] = entry

report["delta"] = {
    metric: report["conditions"]["gain"][metric]["mean"]
    - report["conditions"]["raw"][metric]["mean"]
    for metric in ("UTMOS", "WhiSQA")
}
(out / "level_ab.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
PY

echo "N019_LEVEL_AB_COMPLETE out=$OUT"
