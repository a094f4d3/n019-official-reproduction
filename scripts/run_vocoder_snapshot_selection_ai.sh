#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

OUT="${N019_SELECTION_OUT:-$N019_OFFICIAL_RUNS/vocoder_selection_$(date +%Y%m%d_%H%M%S)}"
SOURCE_MANIFEST="${N019_SELECTION_SOURCE_MANIFEST:?Set N019_SELECTION_SOURCE_MANIFEST}"
UNIT_RECORDS="${N019_SELECTION_UNIT_RECORDS:?Set N019_SELECTION_UNIT_RECORDS}"
TARGET_MAP="${N019_SELECTION_TARGET_MAP:-}"
VOCODER_EMBEDDINGS="${N019_SELECTION_VOCODER_EMBEDDINGS:?Set N019_SELECTION_VOCODER_EMBEDDINGS}"
DURATION_MODEL="${N019_SELECTION_DURATION_MODEL:?Set N019_SELECTION_DURATION_MODEL}"
DURATION_EMBEDDINGS="${N019_SELECTION_DURATION_EMBEDDINGS:-}"
SNAPSHOT_DIR="${N019_SELECTION_SNAPSHOT_DIR:?Set N019_SELECTION_SNAPSHOT_DIR}"
BASELINE_CHECKPOINT="${N019_SELECTION_BASELINE_CHECKPOINT:?Set N019_SELECTION_BASELINE_CHECKPOINT}"
SNAPSHOT_GLOB="${N019_SELECTION_SNAPSHOT_GLOB:-generator_step*.pt}"
LIMIT="${N019_SELECTION_LIMIT:-100}"
VOCODER_TYPE="${N019_SELECTION_VOCODER_TYPE:-nt}"
TARGET_EMBEDDING_KEY="${N019_SELECTION_TARGET_EMBEDDING_KEY:-target_speaker}"
TARGET_EMBEDDING_MODE="${N019_SELECTION_TARGET_EMBEDDING_MODE:-speaker_mean_l2}"
DEVICE="${N019_SELECTION_DEVICE:-cuda}"
MODE="${N019_SELECTION_MODE:-source_reconstruction}"

UTMOS_CODE="$ROOT/vendor/UTMOS22-demo"
UTMOS_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt"
WHISQA_CODE="$ROOT/vendor/WhiSQA"
WHISQA_CHECKPOINT="$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"
WHISPER_SMALL_PATH="${N019_SELECTION_WHISPER_SMALL_PATH:-$N019_VOICE_ROOT/hf_cache/n019_official/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d}"
ASR_MODEL="${N019_SELECTION_ASR_MODEL:-$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local}"

for required in \
  "$SOURCE_MANIFEST" "$UNIT_RECORDS" "$VOCODER_EMBEDDINGS" \
  "$DURATION_MODEL" "$BASELINE_CHECKPOINT" \
  "$UTMOS_CODE/score.py" "$UTMOS_CODE/model.py" \
  "$UTMOS_CODE/lightning_module.py" "$WHISQA_CODE/get_score.py" \
  "$UTMOS_OVERLAY" \
  "$UTMOS_CHECKPOINT" "$WHISQA_CHECKPOINT" "$WHISPER_SMALL_PATH/config.json" \
  "$ASR_MODEL"; do
  test -e "$required" || {
    echo "Missing snapshot-selection input: $required" >&2
    exit 1
  }
done
if [[ "$MODE" == "target_anonymisation" ]]; then
  test -n "$TARGET_MAP" && test -f "$TARGET_MAP" || {
    echo "Target anonymisation mode requires N019_SELECTION_TARGET_MAP" >&2
    exit 1
  }
elif [[ "$MODE" != "source_reconstruction" ]]; then
  echo "N019_SELECTION_MODE must be source_reconstruction or target_anonymisation" >&2
  exit 1
fi
if [[ "$TARGET_EMBEDDING_KEY" == "target_speaker" ]]; then
  test -z "$DURATION_EMBEDDINGS" || test -f "$DURATION_EMBEDDINGS"
fi

mkdir -p "$OUT/candidates"
python - "$SOURCE_MANIFEST" "$OUT/source_selection.jsonl" "$LIMIT" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1])
out = Path(sys.argv[2])
limit = int(sys.argv[3])
if limit <= 0:
    raise SystemExit("N019_SELECTION_LIMIT must be positive")
rows = [line for line in source.read_text(encoding="utf-8").splitlines() if line.strip()]
if len(rows) < limit:
    raise SystemExit(f"Selection manifest has {len(rows)} rows, need {limit}")
out.write_text("\n".join(rows[:limit]) + "\n", encoding="utf-8")
print(f"selection_records={limit} out={out}")
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
print(f"kaldi_dataset={out} rows={len(wav_lines)}")
PY
}

score_candidate() {
  local name="$1"
  local checkpoint="$2"
  local candidate="$OUT/candidates/$name"
  local anon="$candidate/reconstructed"
  local output_json="$anon/reconstructed.jsonl"
  if [[ "$MODE" == "target_anonymisation" ]]; then
    anon="$candidate/anonymised"
    output_json="$anon/anon.jsonl"
  fi
  local dataset="$candidate/vpc/data/selection"
  mkdir -p "$candidate/mos"

  if [[ ! -f "$output_json" ]]; then
    if [[ "$MODE" == "source_reconstruction" ]]; then
      python -u -m n019.reconstruct_vocoder \
        --source-manifest "$OUT/source_selection.jsonl" \
        --unit-records "$UNIT_RECORDS" \
        --vocoder "$checkpoint" \
        --vocoder-type "$VOCODER_TYPE" \
        --vocoder-embeddings "$VOCODER_EMBEDDINGS" \
        --duration-mode pred \
        --duration-model "$DURATION_MODEL" \
        --out-dir "$anon" \
        --limit "$LIMIT" \
        --device "$DEVICE" \
        2>&1 | tee "$candidate/reconstruct.log"
    else
      python -u -m n019.anonymize \
        --source-manifest "$OUT/source_selection.jsonl" \
        --unit-records "$UNIT_RECORDS" \
        --target-map "$TARGET_MAP" \
        --vocoder "$checkpoint" \
        --vocoder-type "$VOCODER_TYPE" \
        --vocoder-embeddings "$VOCODER_EMBEDDINGS" \
        --target-embedding-key "$TARGET_EMBEDDING_KEY" \
        --target-embedding-mode "$TARGET_EMBEDDING_MODE" \
        --duration-mode pred \
        --duration-model "$DURATION_MODEL" \
        --out-dir "$anon" \
        --device "$DEVICE" \
        2>&1 | tee "$candidate/anonymize.log"
    fi
  fi
  test "$(wc -l < "$output_json")" = "$LIMIT"
  make_kaldi_dataset "$output_json" "$dataset"

  if [[ ! -f "$candidate/mos/UTMOS.json" ]]; then
    python -u -m n019.eval_mos \
      --backend utmos \
      --wav-scp "$dataset/wav.scp" \
      --code-source "$UTMOS_CODE" \
      --checkpoint "$UTMOS_CHECKPOINT" \
      --device "$DEVICE" \
      --out "$candidate/mos/UTMOS.json" \
      2>&1 | tee "$candidate/mos/UTMOS.log"
  fi
  if [[ "$name" != "baseline" ]] &&
     [[ ! -f "$candidate/candidate.json" ]] &&
     [[ "${N019_SELECTION_EARLY_REJECT_UTMOS:-0}" == "1" ]]; then
    if python - "$name" "$checkpoint" "$candidate" \
      "$OUT/candidates/baseline/mos/UTMOS.json" \
      "${N019_SELECTION_EARLY_REJECT_UTMOS_GAIN:-0.05}" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

name, checkpoint, candidate, baseline_path, minimum_gain = sys.argv[1:]
candidate = Path(candidate)
checkpoint = Path(checkpoint)
baseline = json.loads(Path(baseline_path).read_text(encoding="utf-8"))
candidate_utmos = json.loads(
    (candidate / "mos/UTMOS.json").read_text(encoding="utf-8")
)
delta = float(candidate_utmos["mean"]) - float(baseline["mean"])
if delta >= float(minimum_gain):
    raise SystemExit(1)
digest = hashlib.sha256()
with checkpoint.open("rb") as handle:
    for block in iter(lambda: handle.read(1024 * 1024), b""):
        digest.update(block)
result = {
    "id": name,
    "checkpoint": str(checkpoint.resolve()),
    "checkpoint_sha256": digest.hexdigest(),
    "count": int(candidate_utmos["count"]),
    "utmos_mean": float(candidate_utmos["mean"]),
    "baseline_utmos_mean": float(baseline["mean"]),
    "delta_utmos": delta,
    "minimum_utmos_gain": float(minimum_gain),
    "reason": "utmos_gate_cannot_pass",
}
(candidate / "early_reject.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY
    then
      echo "N019_SELECTION_EARLY_REJECT_UTMOS name=$name"
      return 0
    fi
  fi
  if [[ ! -f "$candidate/mos/WhiSQA.json" ]]; then
    python -u -m n019.eval_mos \
      --backend whisqa \
      --wav-scp "$dataset/wav.scp" \
      --code-source "$WHISQA_CODE" \
      --checkpoint "$WHISQA_CHECKPOINT" \
      --device "$DEVICE" \
      --out "$candidate/mos/WhiSQA.json" \
      2>&1 | tee "$candidate/mos/WhiSQA.log"
  fi
  if [[ "${N019_SELECTION_RERUN_WER:-0}" == "1" ]]; then
    rm -f "$candidate/WER.json" "$candidate/vpc_asr/wer"
  fi
  if [[ ! -f "$candidate/WER.json" ]]; then
    python -u -m n019.wer_eval_vpc \
      --vpc-data-root "$candidate/vpc/data" \
      --dataset selection \
      --model "$ASR_MODEL" \
      --device "$DEVICE" \
      --expected-count "$LIMIT" \
      --out "$candidate/WER.json" \
      2>&1 | tee "$candidate/wer.log"
  fi

  python - "$name" "$checkpoint" "$candidate" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

name, checkpoint, candidate = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()
utmos = json.loads((candidate / "mos/UTMOS.json").read_text(encoding="utf-8"))
whisqa = json.loads((candidate / "mos/WhiSQA.json").read_text(encoding="utf-8"))
wer = json.loads((candidate / "WER.json").read_text(encoding="utf-8"))
count = int(utmos["count"])
if int(whisqa["count"]) != count or int(wer["utterances"]) != count:
    raise SystemExit(f"Candidate count mismatch: {name}")
result = {
    "id": name,
    "checkpoint": str(checkpoint.resolve()),
    "checkpoint_sha256": sha256(checkpoint),
    "count": count,
    "utmos_mean": float(utmos["mean"]),
    "whisqa_mean": float(whisqa["mean"]),
    "wer_percent": float(wer["wer_percent"]),
}
(candidate / "candidate.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY
}

score_candidate baseline "$BASELINE_CHECKPOINT"
shopt -s nullglob
SNAPSHOTS=("$SNAPSHOT_DIR"/$SNAPSHOT_GLOB)
shopt -u nullglob
if (( ${#SNAPSHOTS[@]} == 0 )); then
  echo "No snapshot matched $SNAPSHOT_DIR/$SNAPSHOT_GLOB" >&2
  exit 1
fi
for checkpoint in "${SNAPSHOTS[@]}"; do
  name="$(basename "$checkpoint" .pt)"
  score_candidate "$name" "$checkpoint"
done

CANDIDATE_ARGS=()
for candidate in "$OUT"/candidates/*/candidate.json; do
  CANDIDATE_ARGS+=(--candidate "$candidate")
done
python -m n019.rank_vocoder_snapshots \
  "${CANDIDATE_ARGS[@]}" \
  --baseline-id baseline \
  --min-utmos-gain "${N019_SELECTION_MIN_UTMOS_GAIN:-0.05}" \
  --min-whisqa-gain "${N019_SELECTION_MIN_WHISQA_GAIN:-0.05}" \
  --max-wer-regression "${N019_SELECTION_MAX_WER_REGRESSION:-0.25}" \
  --out "$OUT/selection.json"

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_RUNS")"
chown -R "$owner" "$OUT"
sha256sum "$OUT/selection.json" "$OUT/selection.md" | tee "$OUT/SHA256SUMS.txt"
echo "N019_VOCODER_SNAPSHOT_SELECTION_COMPLETE out=$OUT"
