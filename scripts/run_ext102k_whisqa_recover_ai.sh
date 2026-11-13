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
UTMOS_SHARD_ROOT="$OUT/mos_shards"
WHISQA_RUN_TAG="${N019_WHISQA_RUN_TAG:-wsr4_20261107_1709}"
SHARD_ROOT="$OUT/mos_whisqa_${WHISQA_RUN_TAG}"
export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"
export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"

test "$(wc -l < "$WAV_SCP")" = 1934
test "$(find "$UTMOS_SHARD_ROOT" -maxdepth 1 -name 'utmos_shard_*.json' | wc -l)" = 8
test -f "$WER_SRC"
test -f "$WHISQA_CHECKPOINT"
test -f "$WHISPER_SMALL_PATH/config.json"
python - <<'PY'
import hydra
import torch
PY

if [[ "${N019_SMOKE_ONLY:-0}" == "1" ]]; then
  SHARD_ROOT="$N019_VOICE_ROOT/tmp/n019_whisqa_device_smoke"
else
  test ! -e "$SHARD_ROOT"
fi
mkdir -p "$SHARD_ROOT"

python - "$WAV_SCP" "$SHARD_ROOT" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1])
root = Path(sys.argv[2])
lines = [line for line in source.read_text().splitlines() if line.strip()]
shards = 8
base, remainder = divmod(len(lines), shards)
offset = 0
for index in range(shards):
    count = base + (1 if index < remainder else 0)
    chunk = lines[offset : offset + count]
    (root / f"whisqa_recover_{index:02d}.wav.scp").write_text(
        "\n".join(chunk) + "\n"
    )
    offset += count
if offset != len(lines):
    raise SystemExit("WhiSQA recovery shard coverage mismatch")
PY

head -n 2 "$WAV_SCP" > "$SHARD_ROOT/whisqa_smoke.wav.scp"
N019_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
  python -u -m n019.eval_mos \
    --backend whisqa \
    --wav-scp "$SHARD_ROOT/whisqa_smoke.wav.scp" \
    --vpc-data-root "$VPC_ROOT" \
    --code-source "$ROOT/vendor/WhiSQA" \
    --checkpoint "$WHISQA_CHECKPOINT" \
    --device cpu \
    --out "$SHARD_ROOT/whisqa_smoke.json" \
    > "$SHARD_ROOT/whisqa_smoke.log" 2>&1

if [[ "${N019_SMOKE_ONLY:-0}" == "1" ]]; then
  echo "WHISQA_DEVICE_SMOKE_OK"
  exit 0
fi

pids=()
for scp in "$SHARD_ROOT"/whisqa_recover_[0-9][0-9].wav.scp; do
  name="$(basename "$scp" .wav.scp)"
  N019_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
    python -u -m n019.eval_mos \
      --backend whisqa \
      --wav-scp "$scp" \
      --vpc-data-root "$VPC_ROOT" \
      --code-source "$ROOT/vendor/WhiSQA" \
      --checkpoint "$WHISQA_CHECKPOINT" \
      --device cpu \
      --out "$SHARD_ROOT/${name}.json" \
      > "$SHARD_ROOT/${name}.log" 2>&1 &
  pids+=("$!")
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then status=1; fi
done
test "$status" = 0

python - "$WAV_SCP" "$WER_SRC" "$OUT" "$UTMOS_SHARD_ROOT" "$SHARD_ROOT" "$UTMOS_CHECKPOINT" "$WHISQA_CHECKPOINT" <<'PY'
import csv
import hashlib
import json
import statistics
import sys
from pathlib import Path

wav_scp = Path(sys.argv[1])
wer_src = Path(sys.argv[2])
out = Path(sys.argv[3])
utmos_shard_root = Path(sys.argv[4])
shard_root = Path(sys.argv[5])
utmos_checkpoint = Path(sys.argv[6])
whisqa_checkpoint = Path(sys.argv[7])

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def merge(paths, checkpoint, expected_backend):
    records = []
    first = None
    for path in paths:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        if first is None:
            first = data
        if data["backend"] != expected_backend:
            raise SystemExit(f"Unexpected backend in {path}: {data['backend']}")
        records.extend(data["records"])
    records.sort(key=lambda item: item["id"])
    if len(records) != 1934 or len({item["id"] for item in records}) != 1934:
        raise SystemExit(f"{expected_backend} records are not 1934 unique IDs")
    values = [float(item["score"]) for item in records]
    return {
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
        "input_sha256": {str(wav_scp.resolve()): sha256(wav_scp)},
        "records": records,
    }

utmos = merge(
    sorted(utmos_shard_root.glob("utmos_shard_*.json")),
    utmos_checkpoint,
    "utmos",
)
whisqa = merge(sorted(shard_root.glob("whisqa_recover_*.json")), whisqa_checkpoint, "whisqa")
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
        "UTMOS is reused from eight completed CPU shards; WhiSQA uses eight recovery CPU shards.",
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
echo "DU_PRED_NT_EXT102K_WHISQA_RECOVER_COMPLETE out=$OUT"
