#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
WAV_SCP="$VPC_ROOT/libri_test_n019_ext102k/wav.scp"
WER_SRC="$N019_OFFICIAL_RUNS/eval/wer_native_cpu_recover/WER.json"
OUT="$N019_OFFICIAL_RUNS/eval/du_pred_nt_ext102k"
UTMOS_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt"
WHISQA_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"
WHISPER_SMALL_PATH="$N019_VOICE_ROOT/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d"
SHARD_ROOT="$OUT/mos_shards"
SHARDS=8
export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"
export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"

for required in \
  "$WAV_SCP" "$WER_SRC" "$UTMOS_CHECKPOINT" "$WHISQA_CHECKPOINT" \
  "$WHISPER_SMALL_PATH/config.json" "$ROOT/vendor/UTMOS22-demo/score.py" \
  "$ROOT/vendor/WhiSQA/models/whisper_ni_predictors.py"; do
  test -f "$required" || {
    echo "Missing sharded MOS input: $required" >&2
    exit 1
  }
done
test "$(wc -l < "$WAV_SCP")" = 1934
python - <<'PY'
import fairseq
import hydra
import omegaconf
import pytorch_lightning
PY

rm -rf "$SHARD_ROOT"
mkdir -p "$SHARD_ROOT"
python - "$WAV_SCP" "$SHARD_ROOT" "$SHARDS" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1])
root = Path(sys.argv[2])
shards = int(sys.argv[3])
lines = [line for line in source.read_text().splitlines() if line.strip()]
base, remainder = divmod(len(lines), shards)
offset = 0
for index in range(shards):
    count = base + (1 if index < remainder else 0)
    shard = lines[offset : offset + count]
    if not shard:
        raise SystemExit(f"Empty shard {index}")
    (root / f"shard_{index:02d}.wav.scp").write_text("\n".join(shard) + "\n")
    offset += count
if offset != len(lines):
    raise SystemExit(f"Shard coverage mismatch: {offset} != {len(lines)}")
PY

run_phase() {
  local backend="$1"
  local checkpoint="$2"
  local pids=()
  local status=0
  for scp in "$SHARD_ROOT"/shard_*.wav.scp; do
    local name
    name="$(basename "$scp" .wav.scp)"
    N019_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
      python -u -m n019.eval_mos \
        --backend "$backend" \
        --wav-scp "$scp" \
        --vpc-data-root "$VPC_ROOT" \
        --code-source "$ROOT/vendor/$([ "$backend" = utmos ] && echo UTMOS22-demo || echo WhiSQA)" \
        --checkpoint "$checkpoint" \
        --device cpu \
        --out "$SHARD_ROOT/${backend}_${name}.json" \
        > "$SHARD_ROOT/${backend}_${name}.log" 2>&1 &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then status=1; fi
  done
  test "$status" = 0
}

run_phase utmos "$UTMOS_CHECKPOINT"
run_phase whisqa "$WHISQA_CHECKPOINT"

python - "$WAV_SCP" "$WER_SRC" "$OUT" "$SHARD_ROOT" "$UTMOS_CHECKPOINT" "$WHISQA_CHECKPOINT" <<'PY'
import csv
import hashlib
import json
import statistics
import sys
from pathlib import Path

wav_scp = Path(sys.argv[1])
wer_src = Path(sys.argv[2])
out = Path(sys.argv[3])
shard_root = Path(sys.argv[4])
utmos_checkpoint = Path(sys.argv[5])
whisqa_checkpoint = Path(sys.argv[6])

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def merge(backend, checkpoint):
    shards = sorted(shard_root.glob(f"{backend}_*.json"))
    if len(shards) != 8:
        raise SystemExit(f"Expected 8 {backend} shards, got {len(shards)}")
    records = []
    for path in shards:
        data = json.loads(path.read_text(encoding="utf-8"))
        records.extend(data["records"])
    records.sort(key=lambda item: item["id"])
    ids = [item["id"] for item in records]
    if len(ids) != 1934 or len(set(ids)) != 1934:
        raise SystemExit(f"{backend} records are not 1934 unique IDs")
    values = [float(item["score"]) for item in records]
    first = json.loads(shards[0].read_text(encoding="utf-8"))
    result = {
        "metric": first["metric"],
        "backend": first["backend"],
        "count": len(values),
        "mean": statistics.fmean(values),
        "stddev": statistics.stdev(values),
        "min": min(values),
        "max": max(values),
        "model_path": str(checkpoint.resolve()),
        "model_sha256": sha256(checkpoint),
        "code_source": first["code_source"],
        "code_sha256": first["code_sha256"],
        "input_sha256": {
            str(wav_scp.resolve()): sha256(wav_scp),
        },
        "records": records,
    }
    return result

utmos = merge("utmos", utmos_checkpoint)
whisqa = merge("whisqa", whisqa_checkpoint)
(out / "mos").mkdir(parents=True, exist_ok=True)
(out / "mos" / "UTMOS.json").write_text(
    json.dumps(utmos, indent=2) + "\n", encoding="utf-8"
)
(out / "mos" / "WhiSQA.json").write_text(
    json.dumps(whisqa, indent=2) + "\n", encoding="utf-8"
)
for name, data in (("UTMOS", utmos), ("WhiSQA", whisqa)):
    with (out / "mos" / f"{name}.tsv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["id", "audio", "wav_scp", "score"],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(data["records"])

wer = json.loads(wer_src.read_text(encoding="utf-8"))
if wer["utterances"] != 1496 or wer["references"] != 1496:
    raise SystemExit("Recovered WER is not 1496 utterances")
(out / "WER.json").write_text(
    json.dumps(wer, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)
paper = {"WER": 7.41, "UTMOS": 3.63, "WhiSQA": 3.69}
step4k = {"WER": 10.333, "UTMOS": 1.2620579278580035, "WhiSQA": 1.847028814125209}
values = {
    "WER": float(wer["wer_percent"]),
    "UTMOS": float(utmos["mean"]),
    "WhiSQA": float(whisqa["mean"]),
}
def comparison(reference):
    result = {}
    for name in ("WER", "UTMOS", "WhiSQA"):
        absolute = values[name] - reference[name]
        result[name] = {
            "reference": reference[name],
            "reproduced": values[name],
            "absolute_difference": absolute,
            "relative_difference_percent": absolute / reference[name] * 100.0,
        }
    return result
summary = {
    "system": "DU-pred-nt-ext102k",
    "vocoder_steps": 102000,
    "vocoder_sha256": "62eb5908aae998f50eed1456a8f6a8f606a88c07627c1d92517f0d072c9ff151",
    "values": values,
    "vs_paper": comparison(paper),
    "vs_step4k_full": comparison(step4k),
    "notes": [
        "WER uses the VPC2024-aligned native CPU path over 1496 utterances.",
        "UTMOS and WhiSQA are CPU-scored over the same 1934 ext102k WAVs.",
        "E-VPC I/L and W-NT I/L were not recomputed in this MOS-only run.",
    ],
}
(out / "quality_metrics.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)
print(json.dumps(summary, indent=2, sort_keys=True))
PY

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
chown -R "$owner" "$OUT"
sha256sum \
  "$OUT/WER.json" \
  "$OUT/mos/UTMOS.json" \
  "$OUT/mos/WhiSQA.json" \
  "$OUT/quality_metrics.json"
echo "DU_PRED_NT_EXT102K_SHARDED_MOS_COMPLETE out=$OUT"
