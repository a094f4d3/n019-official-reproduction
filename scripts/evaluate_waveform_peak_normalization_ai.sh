#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

INPUT_DATASET="${N019_NORM_INPUT_DATASET:?Set N019_NORM_INPUT_DATASET}"
BASELINE_CANDIDATE="${N019_NORM_BASELINE_CANDIDATE:?Set N019_NORM_BASELINE_CANDIDATE}"
OUT="${N019_NORM_OUT:?Set N019_NORM_OUT}"
LIMIT="${N019_NORM_LIMIT:-100}"
DEVICE="${N019_NORM_DEVICE:-cuda}"

UTMOS_CODE="$ROOT/vendor/UTMOS22-demo"
UTMOS_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt"
WHISQA_CODE="$ROOT/vendor/WhiSQA"
WHISQA_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"
WHISPER_SMALL_PATH="$N019_VOICE_ROOT/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d"
ASR_MODEL="${N019_NORM_ASR_MODEL:-$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local}"

for required in \
  "$INPUT_DATASET/wav.scp" "$INPUT_DATASET/text" "$BASELINE_CANDIDATE" \
  "$UTMOS_CODE/score.py" "$UTMOS_CODE/model.py" \
  "$UTMOS_CODE/lightning_module.py" "$WHISQA_CODE/get_score.py" \
  "$UTMOS_OVERLAY" "$UTMOS_CHECKPOINT" "$WHISQA_CHECKPOINT" \
  "$WHISPER_SMALL_PATH/config.json" "$ASR_MODEL"; do
  test -e "$required" || {
    echo "Missing waveform-normalization input: $required" >&2
    exit 1
  }
done

mkdir -p "$OUT/mos"
python - "$INPUT_DATASET" "$BASELINE_CANDIDATE" "$OUT" "$LIMIT" <<'PY'
import json
import shutil
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

source = Path(sys.argv[1])
candidate_path = Path(sys.argv[2])
out = Path(sys.argv[3])
limit = int(sys.argv[4])

candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
if int(candidate["count"]) != limit:
    raise SystemExit(
        f"baseline candidate count={candidate['count']}, expected {limit}"
    )

wav_rows = [
    line.split(maxsplit=1)
    for line in (source / "wav.scp").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
text_rows = [
    line.split(maxsplit=1)
    for line in (source / "text").read_text(encoding="utf-8").splitlines()
    if line.strip()
]
if len(wav_rows) != limit or len(text_rows) != limit:
    raise SystemExit(
        f"input wav/text counts={len(wav_rows)}/{len(text_rows)}, expected {limit}"
    )
if {key for key, _ in wav_rows} != {key for key, _ in text_rows}:
    raise SystemExit("input wav/text IDs differ")

wav_dir = out / "normalized" / "wav"
dataset = out / "normalized" / "vpc" / "data" / "selection"
wav_dir.mkdir(parents=True, exist_ok=True)
dataset.mkdir(parents=True, exist_ok=True)

normalized_wav_rows = []
peaks = []
for identifier, raw_path in wav_rows:
    path = Path(raw_path)
    if not path.is_file():
        raise SystemExit(f"missing input wav: {path}")
    audio, sample_rate = sf.read(path, dtype="float32", always_2d=False)
    if sample_rate != 16000:
        raise SystemExit(f"{path}: expected 16 kHz, got {sample_rate}")
    if audio.ndim != 1:
        raise SystemExit(f"{path}: expected mono audio")
    peak = float(np.max(np.abs(audio)))
    if not np.isfinite(audio).all() or peak <= 1e-8:
        raise SystemExit(f"{path}: invalid waveform peak={peak}")
    normalized = audio / peak
    target = wav_dir / path.name
    sf.write(target, normalized, sample_rate)
    normalized_wav_rows.append(f"{identifier} {target.resolve()}")
    peaks.append(peak)

(dataset / "wav.scp").write_text(
    "\n".join(normalized_wav_rows) + "\n",
    encoding="utf-8",
)
shutil.copyfile(source / "text", dataset / "text")
summary = {
    "count": len(normalized_wav_rows),
    "normalization": "librosa-util-normalize-equivalent-inf-peak",
    "source_peak_mean": float(np.mean(peaks)),
    "source_peak_min": float(np.min(peaks)),
    "source_peak_max": float(np.max(peaks)),
    "baseline": {
        "UTMOS": float(candidate["utmos_mean"]),
        "WhiSQA": float(candidate["whisqa_mean"]),
        "WER_percent": float(candidate["wer_percent"]),
    },
}
(out / "normalization_summary.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY

export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"
export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"
DATASET="$OUT/normalized/vpc/data/selection"

python -u -m n019.eval_mos \
  --backend utmos --wav-scp "$DATASET/wav.scp" \
  --code-source "$UTMOS_CODE" --checkpoint "$UTMOS_CHECKPOINT" \
  --device "$DEVICE" --out "$OUT/mos/UTMOS.json" \
  2>&1 | tee "$OUT/mos/UTMOS.log"
python -u -m n019.eval_mos \
  --backend whisqa --wav-scp "$DATASET/wav.scp" \
  --code-source "$WHISQA_CODE" --checkpoint "$WHISQA_CHECKPOINT" \
  --device "$DEVICE" --out "$OUT/mos/WhiSQA.json" \
  2>&1 | tee "$OUT/mos/WhiSQA.log"
python -u -m n019.wer_eval_vpc \
  --vpc-data-root "$OUT/normalized/vpc/data" --dataset selection \
  --model "$ASR_MODEL" --device "$DEVICE" \
  --expected-count "$LIMIT" --out "$OUT/WER.json" \
  2>&1 | tee "$OUT/wer.log"

python - "$OUT" <<'PY'
import json
import statistics
import sys
from pathlib import Path

root = Path(sys.argv[1])
summary = json.loads(
    (root / "normalization_summary.json").read_text(encoding="utf-8")
)
utmos = json.loads((root / "mos/UTMOS.json").read_text(encoding="utf-8"))
whisqa = json.loads((root / "mos/WhiSQA.json").read_text(encoding="utf-8"))
wer = json.loads((root / "WER.json").read_text(encoding="utf-8"))
count = int(summary["count"])
if any(int(score["count"]) != count for score in (utmos, whisqa)):
    raise SystemExit("MOS count mismatch")
if int(wer["utterances"]) != count:
    raise SystemExit("WER count mismatch")
normalized = {
    "UTMOS": float(utmos["mean"]),
    "WhiSQA": float(whisqa["mean"]),
    "WER_percent": float(wer["wer_percent"]),
}
baseline = summary["baseline"]
result = {
    "count": count,
    "baseline": baseline,
    "normalized": normalized,
    "delta": {
        metric: normalized[metric] - baseline[metric]
        for metric in ("UTMOS", "WhiSQA", "WER_percent")
    },
    "source_peak_mean": summary["source_peak_mean"],
    "normalization": summary["normalization"],
}
(root / "comparison.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
(root / "comparison.md").write_text(
    "# Waveform Peak-Normalization A/B\n\n"
    f"- baseline: UTMOS {baseline['UTMOS']:.6f}, "
    f"WhiSQA {baseline['WhiSQA']:.6f}, WER {baseline['WER_percent']:.6f}%\n"
    f"- normalized: UTMOS {normalized['UTMOS']:.6f}, "
    f"WhiSQA {normalized['WhiSQA']:.6f}, WER {normalized['WER_percent']:.6f}%\n"
    f"- delta: UTMOS {result['delta']['UTMOS']:+.6f}, "
    f"WhiSQA {result['delta']['WhiSQA']:+.6f}, "
    f"WER {result['delta']['WER_percent']:+.6f} pp\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

chown -R "$(stat -c '%u:%g' "$N019_OFFICIAL_RUNS")" "$OUT"
sha256sum "$OUT/comparison.json" "$OUT/comparison.md" | tee "$OUT/SHA256SUMS.txt"
echo "N019_WAVEFORM_NORMALIZATION_AB_COMPLETE out=$OUT"
