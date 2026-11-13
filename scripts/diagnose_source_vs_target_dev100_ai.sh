#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

OUT="${N019_SOURCE_TARGET_DIAG_OUT:?Set N019_SOURCE_TARGET_DIAG_OUT}"
SOURCE_MANIFEST="${N019_SOURCE_TARGET_DIAG_SOURCES:?Set N019_SOURCE_TARGET_DIAG_SOURCES}"
UNIT_RECORDS="${N019_SOURCE_TARGET_DIAG_UNITS:?Set N019_SOURCE_TARGET_DIAG_UNITS}"
TARGET_MAP="${N019_SOURCE_TARGET_DIAG_TARGET_MAP:?Set N019_SOURCE_TARGET_DIAG_TARGET_MAP}"
SOURCE_EMBEDDINGS="${N019_SOURCE_TARGET_DIAG_SOURCE_EMBEDDINGS:?Set source speaker embeddings}"
TARGET_EMBEDDINGS="${N019_SOURCE_TARGET_DIAG_TARGET_EMBEDDINGS:?Set target speaker embeddings}"
VOCODER="${N019_SOURCE_TARGET_DIAG_VOCODER:?Set the fixed vocoder checkpoint}"
LIMIT="${N019_SOURCE_TARGET_DIAG_LIMIT:-100}"
DEVICE="${N019_SOURCE_TARGET_DIAG_DEVICE:-cuda}"
VOCODER_TYPE="${N019_SOURCE_TARGET_DIAG_VOCODER_TYPE:-nt}"

UTMOS_CODE="$ROOT/vendor/UTMOS22-demo"
UTMOS_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt"
WHISQA_CODE="$ROOT/vendor/WhiSQA"
WHISQA_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"
WHISPER_SMALL_PATH="${N019_SOURCE_TARGET_DIAG_WHISPER_SMALL_PATH:-$N019_VOICE_ROOT/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d}"
ASR_MODEL="${N019_SOURCE_TARGET_DIAG_ASR_MODEL:-$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local}"

for required in \
  "$SOURCE_MANIFEST" "$UNIT_RECORDS" "$TARGET_MAP" "$SOURCE_EMBEDDINGS" \
  "$TARGET_EMBEDDINGS" "$VOCODER" "$UTMOS_CODE/score.py" \
  "$UTMOS_CODE/model.py" "$UTMOS_CODE/lightning_module.py" \
  "$WHISQA_CODE/get_score.py" "$UTMOS_OVERLAY" "$UTMOS_CHECKPOINT" \
  "$WHISQA_CHECKPOINT" "$WHISPER_SMALL_PATH/config.json" "$ASR_MODEL"; do
  test -e "$required" || {
    echo "Missing source-vs-target diagnostic input: $required" >&2
    exit 1
  }
done

mkdir -p "$OUT/source" "$OUT/target"
python - \
  "$SOURCE_MANIFEST" "$TARGET_MAP" "$SOURCE_EMBEDDINGS" "$TARGET_EMBEDDINGS" \
  "$OUT" "$LIMIT" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

source_path, target_path, source_npz, target_npz, out_dir = map(
    Path, sys.argv[1:6]
)
limit = int(sys.argv[6])
sources = [
    json.loads(line)
    for line in source_path.read_text(encoding="utf-8").splitlines()
    if line.strip()
][:limit]
targets = [
    json.loads(line)
    for line in target_path.read_text(encoding="utf-8").splitlines()
    if line.strip()
]
source_ids = [str(row["id"]) for row in sources]
target_by_source = {str(row["source_id"]): row for row in targets}
if len(set(source_ids)) != limit or len(sources) != limit:
    raise SystemExit("Source manifest does not contain the required unique rows")
if set(source_ids) != set(target_by_source):
    missing = sorted(set(source_ids) - set(target_by_source))
    extra = sorted(set(target_by_source) - set(source_ids))
    raise SystemExit(f"Source/target-map mismatch: missing={missing} extra={extra}")

source_map = []
for row in sources:
    speaker = str(row["speaker"])
    source_map.append(
        {
            "source_id": str(row["id"]),
            "source_speaker": speaker,
            "source_audio": str(row["audio"]),
            "target_id": speaker,
            "target_speaker": speaker,
            "target_audio": str(row["audio"]),
        }
    )
selected_targets = [target_by_source[identifier] for identifier in source_ids]
out_dir.mkdir(parents=True, exist_ok=True)
(out_dir / "source_selection.jsonl").write_text(
    "".join(json.dumps(row, sort_keys=True) + "\n" for row in sources),
    encoding="utf-8",
)
(out_dir / "source_target_map.jsonl").write_text(
    "".join(json.dumps(row, sort_keys=True) + "\n" for row in source_map),
    encoding="utf-8",
)
(out_dir / "target_selection_map.jsonl").write_text(
    "".join(json.dumps(row, sort_keys=True) + "\n" for row in selected_targets),
    encoding="utf-8",
)

checks = (
    ("source", source_npz, {row["target_speaker"] for row in source_map}),
    ("target", target_npz, {row["target_speaker"] for row in selected_targets}),
)
preflight = {}
for name, path, required in checks:
    with np.load(path, allow_pickle=False) as archive:
        missing = sorted(required - set(archive.files))
        if missing:
            raise SystemExit(
                f"{name} embedding keys missing: {len(missing)} first={missing[0]}"
            )
        matrix = np.stack([archive[key] for key in sorted(required)])
    if matrix.shape[1:] != (250,):
        raise SystemExit(f"{name} embeddings are not 250-D")
    if not np.isfinite(matrix).all():
        raise SystemExit(f"{name} embeddings contain non-finite values")
    norms = np.linalg.norm(matrix, axis=1)
    if not np.allclose(norms, 1.0, atol=1e-4):
        raise SystemExit(f"{name} embeddings are not unit norm")
    preflight[name] = {
        "keys": len(required),
        "minimum_norm": float(norms.min()),
        "maximum_norm": float(norms.max()),
    }

summary = {
    "rows": len(sources),
    "source_speakers": len({row["speaker"] for row in sources}),
    "target_speakers": len({row["target_speaker"] for row in selected_targets}),
    "source_manifest_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
    "target_map_sha256": hashlib.sha256(target_path.read_bytes()).hexdigest(),
    "preflight": preflight,
}
(out_dir / "preflight.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2, sort_keys=True))
PY

export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"
export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"

make_kaldi_dataset() {
  local anon_jsonl="$1"
  local dataset_dir="$2"
  python - "$anon_jsonl" "$dataset_dir" <<'PY'
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
if not wav_lines:
    raise SystemExit(f"No rows in {anon}")
(out / "wav.scp").write_text("\n".join(wav_lines) + "\n", encoding="utf-8")
(out / "text").write_text("\n".join(text_lines) + "\n", encoding="utf-8")
PY
}

score_variant() {
  local name="$1"
  local target_map="$2"
  local embeddings="$3"
  local embedding_key="$4"
  local embedding_mode="$5"
  local root="$OUT/$name"
  local anon="$root/anonymised"
  local dataset="$root/vpc/data/selection"
  mkdir -p "$root/mos"

  python -u -m n019.anonymize \
    --source-manifest "$OUT/source_selection.jsonl" \
    --unit-records "$UNIT_RECORDS" \
    --target-map "$target_map" \
    --vocoder "$VOCODER" \
    --vocoder-type "$VOCODER_TYPE" \
    --vocoder-embeddings "$embeddings" \
    --target-embedding-key "$embedding_key" \
    --target-embedding-mode "$embedding_mode" \
    --duration-mode orig \
    --out-dir "$anon" \
    --device "$DEVICE" \
    2>&1 | tee "$root/anonymize.log"

  test "$(wc -l < "$anon/anon.jsonl")" = "$LIMIT"
  make_kaldi_dataset "$anon/anon.jsonl" "$dataset"

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

  python - "$name" "$root" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

name, root = sys.argv[1], Path(sys.argv[2])
utmos = json.loads((root / "mos/UTMOS.json").read_text(encoding="utf-8"))
whisqa = json.loads((root / "mos/WhiSQA.json").read_text(encoding="utf-8"))
wer = json.loads((root / "WER.json").read_text(encoding="utf-8"))
count = int(utmos["count"])
if int(whisqa["count"]) != count or int(wer["utterances"]) != count:
    raise SystemExit(f"Metric count mismatch: {name}")
result = {
    "id": name,
    "count": count,
    "utmos_mean": float(utmos["mean"]),
    "whisqa_mean": float(whisqa["mean"]),
    "wer_percent": float(wer["wer_percent"]),
    "anon_sha256": hashlib.sha256(
        (root / "anonymised/anon.jsonl").read_bytes()
    ).hexdigest(),
}
(root / "candidate.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY
}

score_variant \
  source \
  "$OUT/source_target_map.jsonl" \
  "$SOURCE_EMBEDDINGS" \
  target_speaker \
  source_speaker_mean_l2
score_variant \
  target \
  "$OUT/target_selection_map.jsonl" \
  "$TARGET_EMBEDDINGS" \
  target_speaker \
  speaker_mean_l2

python - "$OUT" "$VOCODER" <<'PY'
import hashlib
import json
import statistics
import sys
from pathlib import Path

root = Path(sys.argv[1])
vocoder = Path(sys.argv[2])
source = json.loads((root / "source/candidate.json").read_text(encoding="utf-8"))
target = json.loads((root / "target/candidate.json").read_text(encoding="utf-8"))
if int(source["count"]) != int(target["count"]):
    raise SystemExit("Candidate counts differ")
result = {
    "system": "source-vs-target-conditioning",
    "duration_mode": "orig",
    "count": int(source["count"]),
    "vocoder": str(vocoder.resolve()),
    "vocoder_sha256": hashlib.sha256(vocoder.read_bytes()).hexdigest(),
    "source": source,
    "target": target,
}
for metric in ("utmos_mean", "whisqa_mean", "wer_percent"):
    result[f"target_minus_source_{metric}"] = target[metric] - source[metric]
for metric in ("UTMOS", "WhiSQA"):
    left = {
        str(row["id"]): float(row["score"])
        for row in json.loads(
            (root / "source/mos" / f"{metric}.json").read_text(encoding="utf-8")
        )["records"]
    }
    right = {
        str(row["id"]): float(row["score"])
        for row in json.loads(
            (root / "target/mos" / f"{metric}.json").read_text(encoding="utf-8")
        )["records"]
    }
    if set(left) != set(right):
        raise SystemExit(f"{metric} paired IDs differ")
    deltas = [right[key] - left[key] for key in sorted(left)]
    result[f"{metric}_paired_delta_mean"] = statistics.fmean(deltas)
    result[f"{metric}_paired_delta_stderr"] = (
        statistics.stdev(deltas) / (len(deltas) ** 0.5)
    )
(root / "comparison.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
(root / "comparison.md").write_text(
    "# Source vs Target Conditioning\n\n"
    f"- source: UTMOS {source['utmos_mean']:.6f}, "
    f"WhiSQA {source['whisqa_mean']:.6f}, WER {source['wer_percent']:.6f}%\n"
    f"- target: UTMOS {target['utmos_mean']:.6f}, "
    f"WhiSQA {target['whisqa_mean']:.6f}, WER {target['wer_percent']:.6f}%\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_RUNS")"
chown -R "$owner" "$OUT"
sha256sum "$OUT/comparison.json" "$OUT/comparison.md" \
  | tee "$OUT/SHA256SUMS.txt"
echo "N019_SOURCE_TARGET_DIAGNOSTIC_COMPLETE out=$OUT"
