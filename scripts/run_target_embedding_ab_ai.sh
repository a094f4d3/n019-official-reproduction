#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

OUT="${N019_TARGET_AB_OUT:-$N019_OFFICIAL_RUNS/target_embedding_ab_$(date +%Y%m%d_%H%M%S)}"
SOURCE_MANIFEST="${N019_TARGET_AB_SOURCE_MANIFEST:?Set N019_TARGET_AB_SOURCE_MANIFEST}"
UNIT_RECORDS="${N019_TARGET_AB_UNIT_RECORDS:?Set N019_TARGET_AB_UNIT_RECORDS}"
TARGET_MAP="${N019_TARGET_AB_TARGET_MAP:?Set N019_TARGET_AB_TARGET_MAP}"
VOCODER="${N019_TARGET_AB_VOCODER:?Set N019_TARGET_AB_VOCODER}"
DURATION_MODEL="${N019_TARGET_AB_DURATION_MODEL:?Set N019_TARGET_AB_DURATION_MODEL}"
UTTERANCE_EMBEDDINGS="${N019_TARGET_AB_UTTERANCE_EMBEDDINGS:?Set N019_TARGET_AB_UTTERANCE_EMBEDDINGS}"
SPEAKER_EMBEDDINGS="${N019_TARGET_AB_SPEAKER_EMBEDDINGS:?Set N019_TARGET_AB_SPEAKER_EMBEDDINGS}"
UTTERANCE_NAME="${N019_TARGET_AB_UTTERANCE_NAME:-utterance}"
SPEAKER_NAME="${N019_TARGET_AB_SPEAKER_NAME:-speaker_mean_l2}"
UTTERANCE_KEY="${N019_TARGET_AB_UTTERANCE_KEY:-target_id}"
SPEAKER_KEY="${N019_TARGET_AB_SPEAKER_KEY:-target_speaker}"
UTTERANCE_MODE="${N019_TARGET_AB_UTTERANCE_MODE:-utterance}"
SPEAKER_MODE="${N019_TARGET_AB_SPEAKER_MODE:-speaker_mean_l2}"
LIMIT="${N019_TARGET_AB_LIMIT:-100}"
DEVICE="${N019_TARGET_AB_DEVICE:-cuda}"
VOCODER_TYPE="${N019_TARGET_AB_VOCODER_TYPE:-nt}"

UTMOS_CODE="$ROOT/vendor/UTMOS22-demo"
UTMOS_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt"
WHISQA_CODE="$ROOT/vendor/WhiSQA"
WHISQA_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"
WHISPER_SMALL_PATH="$N019_VOICE_ROOT/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d"
ASR_MODEL="${N019_TARGET_AB_ASR_MODEL:-$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local}"

test "$(python - "$SOURCE_MANIFEST" "$LIMIT" <<'PY'
import sys
from pathlib import Path
limit = int(sys.argv[2])
rows = [line for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines() if line.strip()]
if len(rows) < limit:
    raise SystemExit(1)
print(limit)
PY
)" = "$LIMIT"

for required in \
  "$UNIT_RECORDS" "$TARGET_MAP" "$VOCODER" "$DURATION_MODEL" \
  "$UTTERANCE_EMBEDDINGS" "$SPEAKER_EMBEDDINGS" \
  "$UTMOS_CODE/score.py" "$UTMOS_CODE/model.py" \
  "$UTMOS_CODE/lightning_module.py" "$WHISQA_CODE/get_score.py" \
  "$UTMOS_OVERLAY" "$UTMOS_CHECKPOINT" \
  "$WHISQA_CHECKPOINT" "$WHISPER_SMALL_PATH/config.json" "$ASR_MODEL"; do
  test -e "$required" || {
    echo "Missing target-embedding A/B input: $required" >&2
    exit 1
  }
done

# Fail before loading models if a variant's key/mode does not match the NPZ.
python - \
  "$TARGET_MAP" \
  "$UTTERANCE_EMBEDDINGS" "$UTTERANCE_KEY" "$UTTERANCE_MODE" \
  "$SPEAKER_EMBEDDINGS" "$SPEAKER_KEY" "$SPEAKER_MODE" <<'PY'
import json
import sys
from pathlib import Path

import numpy as np

target_map = Path(sys.argv[1])
variants = (
    ("variant", Path(sys.argv[2]), sys.argv[3], sys.argv[4]),
    ("speaker", Path(sys.argv[5]), sys.argv[6], sys.argv[7]),
)
rows = [
    json.loads(line)
    for line in target_map.read_text(encoding="utf-8").splitlines()
    if line.strip()
]
for name, path, key_field, mode in variants:
    required_keys = {str(row[key_field]) for row in rows}
    with np.load(path, allow_pickle=True) as arrays:
        present = set(arrays.files)
        missing = sorted(required_keys - present)
        if missing:
            raise SystemExit(
                f"{name} embedding mismatch: key_field={key_field} "
                f"mode={mode} missing={len(missing)} example={missing[0]}"
            )
        matrix = np.stack([arrays[key] for key in sorted(required_keys)])
    if matrix.shape[1:] != (250,):
        raise SystemExit(f"{name} embedding dimension is not 250-D")
    if not np.isfinite(matrix).all():
        raise SystemExit(f"{name} embedding contains non-finite values")
    norms = np.linalg.norm(matrix, axis=1)
    if not np.allclose(norms, 1.0, atol=1e-4):
        raise SystemExit(f"{name} embedding is not unit norm")
    print(
        f"target_embedding_preflight={name} keys={len(required_keys)} "
        f"key_field={key_field} mode={mode}"
    )
PY

mkdir -p "$OUT"
python - "$SOURCE_MANIFEST" "$OUT/source_selection.jsonl" "$LIMIT" <<'PY'
import sys
from pathlib import Path
rows = [line for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines() if line.strip()]
Path(sys.argv[2]).write_text("\n".join(rows[:int(sys.argv[3])]) + "\n", encoding="utf-8")
PY

export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"
export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"

score_variant() {
  local name="$1"
  local embeddings="$2"
  local key="$3"
  local mode="$4"
  local root="$OUT/$name"
  local anon="$root/anonymised"
  local dataset="$root/vpc/data/selection"
  mkdir -p "$root/mos"

  python -u -m n019.anonymize \
    --source-manifest "$OUT/source_selection.jsonl" \
    --unit-records "$UNIT_RECORDS" \
    --target-map "$TARGET_MAP" \
    --vocoder "$VOCODER" \
    --vocoder-type "$VOCODER_TYPE" \
    --vocoder-embeddings "$embeddings" \
    --target-embedding-key "$key" \
    --target-embedding-mode "$mode" \
    --duration-mode pred \
    --duration-model "$DURATION_MODEL" \
    --out-dir "$anon" \
    --device "$DEVICE" \
    2>&1 | tee "$root/anonymize.log"

  python - "$anon/anon.jsonl" "$dataset" <<'PY'
import json
import sys
from pathlib import Path
anon = Path(sys.argv[1])
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
wav_lines = []
text_lines = []
for raw in anon.read_text(encoding="utf-8").splitlines():
    if not raw.strip():
        continue
    row = json.loads(raw)
    identifier = str(row["id"])
    wav_lines.append(f"{identifier} {Path(row['audio']).resolve()}")
    text = str(row.get("text") or "").strip()
    if not text:
        source_audio = Path(row.get("source_audio") or row["audio"]).resolve()
        transcript = source_audio.with_suffix(".normalized.txt")
        if not transcript.is_file():
            raise SystemExit(f"Missing source transcript: {transcript}")
        text = transcript.read_text(encoding="utf-8").strip().upper()
    if not text:
        raise SystemExit(f"Empty transcript for {identifier}")
    text_lines.append(f"{identifier} {text}")
(out / "wav.scp").write_text("\n".join(wav_lines) + "\n", encoding="utf-8")
(out / "text").write_text("\n".join(text_lines) + "\n", encoding="utf-8")
PY

  python -u -m n019.eval_mos \
    --backend utmos --wav-scp "$dataset/wav.scp" \
    --code-source "$UTMOS_CODE" --checkpoint "$UTMOS_CHECKPOINT" \
    --device "$DEVICE" --out "$root/mos/UTMOS.json" \
    2>&1 | tee "$root/mos/UTMOS.log"
  python -u -m n019.eval_mos \
    --backend whisqa --wav-scp "$dataset/wav.scp" \
    --code-source "$WHISQA_CODE" --checkpoint "$WHISQA_CHECKPOINT" \
    --device "$DEVICE" --out "$root/mos/WhiSQA.json" \
    2>&1 | tee "$root/mos/WhiSQA.log"
  python -u -m n019.wer_eval_vpc \
    --vpc-data-root "$root/vpc/data" --dataset selection \
    --model "$ASR_MODEL" --device "$DEVICE" \
    --expected-count "$LIMIT" --out "$root/WER.json" \
    2>&1 | tee "$root/wer.log"
}

score_variant "$UTTERANCE_NAME" "$UTTERANCE_EMBEDDINGS" "$UTTERANCE_KEY" "$UTTERANCE_MODE"
score_variant "$SPEAKER_NAME" "$SPEAKER_EMBEDDINGS" "$SPEAKER_KEY" "$SPEAKER_MODE"

python - "$OUT" "$UTTERANCE_NAME" "$SPEAKER_NAME" <<'PY'
import json
import statistics
import sys
from pathlib import Path

root = Path(sys.argv[1])
left_name = sys.argv[2]
right_name = sys.argv[3]
def load(name):
    base = root / name
    return {
        "UTMOS": json.loads((base / "mos/UTMOS.json").read_text(encoding="utf-8")),
        "WhiSQA": json.loads((base / "mos/WhiSQA.json").read_text(encoding="utf-8")),
        "WER": json.loads((base / "WER.json").read_text(encoding="utf-8")),
    }
utterance = load(left_name)
speaker = load(right_name)
count = int(utterance["UTMOS"]["count"])
for variant in (utterance, speaker):
    if any(int(variant[name]["count" if name != "WER" else "utterances"]) != count for name in ("UTMOS", "WhiSQA", "WER")):
        raise SystemExit(f"Count mismatch in {variant}")
result = {
    "system": "target-embedding-pooling-ab",
    "count": count,
    left_name: {
        "UTMOS": float(utterance["UTMOS"]["mean"]),
        "WhiSQA": float(utterance["WhiSQA"]["mean"]),
        "WER_percent": float(utterance["WER"]["wer_percent"]),
    },
    right_name: {
        "UTMOS": float(speaker["UTMOS"]["mean"]),
        "WhiSQA": float(speaker["WhiSQA"]["mean"]),
        "WER_percent": float(speaker["WER"]["wer_percent"]),
    },
}
for metric in ("UTMOS", "WhiSQA", "WER_percent"):
    result[f"delta_{metric}"] = result[right_name][metric] - result[left_name][metric]
for metric in ("UTMOS", "WhiSQA"):
    left = {
        str(row["id"]): float(row["score"])
        for row in utterance[metric]["records"]
    }
    right = {
        str(row["id"]): float(row["score"])
        for row in speaker[metric]["records"]
    }
    if set(left) != set(right):
        raise SystemExit(f"{metric} paired IDs differ")
    deltas = [right[key] - left[key] for key in sorted(left)]
    if len(deltas) < 2:
        raise SystemExit(f"{metric} needs at least two paired values")
    result[f"{metric}_paired_delta_mean"] = statistics.fmean(deltas)
    result[f"{metric}_paired_delta_stderr"] = (
        statistics.stdev(deltas) / (len(deltas) ** 0.5)
    )
(root / "comparison.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(root / "comparison.md").write_text(
    "# Target Embedding Pooling A/B\n\n"
    f"- {left_name}: UTMOS {result[left_name]['UTMOS']:.6f}, "
    f"WhiSQA {result[left_name]['WhiSQA']:.6f}, "
    f"WER {result[left_name]['WER_percent']:.6f}%\n"
    f"- {right_name}: UTMOS {result[right_name]['UTMOS']:.6f}, "
    f"WhiSQA {result[right_name]['WhiSQA']:.6f}, "
    f"WER {result[right_name]['WER_percent']:.6f}%\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_RUNS")"
chown -R "$owner" "$OUT"
sha256sum "$OUT/comparison.json" "$OUT/comparison.md" | tee "$OUT/SHA256SUMS.txt"
echo "N019_TARGET_EMBEDDING_AB_COMPLETE out=$OUT"
