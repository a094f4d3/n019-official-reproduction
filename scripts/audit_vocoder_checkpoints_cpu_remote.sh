#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

DATA="$N019_OFFICIAL_DATA/processed"
RUNS="$N019_OFFICIAL_RUNS"
OUT="${N019_CHECKPOINT_AUDIT_OUT:-$RUNS/audit/vocoder_checkpoint_cpu_20261106}"
SAMPLE_COUNT="${N019_CHECKPOINT_AUDIT_SAMPLES:-25}"
DEVICE="${N019_CHECKPOINT_AUDIT_DEVICE:-cpu}"
RUN_MOS="${N019_CHECKPOINT_AUDIT_MOS:-0}"
OWNER="$(stat -c '%u:%g' "$RUNS")"

SOURCE="$DATA/manifests/libri_test.jsonl"
UNITS="$DATA/units/libri_test_paperfix/unit_records.jsonl"
TARGET_MAP="$DATA/targets/libri_test_target_map_paperfix.jsonl"
TARGET_EMBEDDINGS="$DATA/embeddings/libri_test_target_nt_utterance_paperfix/nt_utterance_embeddings.npz"
DURATION_MODEL="$RUNS/duration_pred_paperfix/best.pt"

declare -A MODELS=(
  [paperfix_best_step4000]="$RUNS/vocoder_nt_paperfix/best.pt"
  [paperfix_last_step34000]="${N019_PAPERFIX_STEP34K_CHECKPOINT:-$RUNS/vocoder_nt_paperfix/generator_step34000_diagnostic.pt}"
  [paperfix_ext_best_step102000]="${N019_PAPERFIX_EXT_STEP102K_CHECKPOINT:-$RUNS/audit/vocoder_checkpoint_cpu_20261106/checkpoints/paperfix_ext_best_step102000.pt}"
  [main_best_step76000]="$RUNS/vocoder_nt_main/best.pt"
)

for required in \
  "$SOURCE" \
  "$UNITS" \
  "$TARGET_MAP" \
  "$TARGET_EMBEDDINGS" \
  "$DURATION_MODEL"; do
  test -f "$required" || {
    echo "Missing checkpoint-audit input: $required" >&2
    exit 1
  }
done
MODEL_NAMES=()
if [[ -n "${N019_CHECKPOINT_AUDIT_MODEL_NAMES:-}" ]]; then
  IFS=',' read -r -a MODEL_NAMES <<< "$N019_CHECKPOINT_AUDIT_MODEL_NAMES"
else
  MODEL_NAMES=("${!MODELS[@]}")
fi

FOUND_MODELS=()
for name in "${MODEL_NAMES[@]}"; do
  if [[ -z "${MODELS[$name]:-}" ]]; then
    echo "Unknown checkpoint audit model: $name" >&2
    exit 1
  fi
  model="${MODELS[$name]}"
  if [[ -f "$model" ]]; then
    FOUND_MODELS+=("$name")
  else
    echo "SKIP_MISSING_CHECKPOINT name=$name path=$model"
  fi
done
if (( ${#FOUND_MODELS[@]} == 0 )); then
  echo "No checkpoints found for audit" >&2
  exit 1
fi

mkdir -p "$OUT/inputs"
if [[ "$(id -u)" == "0" ]]; then
  trap 'chown -R "$OWNER" "$OUT" || true' EXIT
fi
python - "$SOURCE" "$UNITS" "$TARGET_MAP" "$OUT/inputs" "$SAMPLE_COUNT" <<'PY'
import json
import sys
from pathlib import Path

source_path, units_path, map_path, out_dir, sample_count = sys.argv[1:]
out_dir = Path(out_dir)
sample_count = int(sample_count)

def read_jsonl(path: Path) -> list[dict]:
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]

def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in rows),
        encoding="utf-8",
    )

sources = read_jsonl(Path(source_path))
if len(sources) != 1934:
    raise SystemExit(f"Expected 1934 source rows, got {len(sources)}")
indices = sorted({
    round(index * (len(sources) - 1) / max(1, sample_count - 1))
    for index in range(sample_count)
})
selected = [sources[index] for index in indices]
ids = {str(row["id"]) for row in selected}

units = {str(row["id"]): row for row in read_jsonl(Path(units_path))}
mappings = {str(row["source_id"]): row for row in read_jsonl(Path(map_path))}
if not ids <= units.keys():
    raise SystemExit("Selected source IDs are missing unit records")
if not ids <= mappings.keys():
    raise SystemExit("Selected source IDs are missing target mappings")

write_jsonl(out_dir / "source.jsonl", selected)
write_jsonl(out_dir / "units.jsonl", [units[key] for key in sorted(ids)])
write_jsonl(out_dir / "target_map.jsonl", [mappings[key] for key in sorted(ids)])
print(f"CHECKPOINT_AUDIT_INPUTS_OK samples={len(selected)} ids={indices}")
PY

for name in "${FOUND_MODELS[@]}"; do
  model="${MODELS[$name]}"
  model_out="$OUT/$name"
  mkdir -p "$model_out"
  sha256sum "$model" | tee "$model_out/model.sha256"
  python -u -m n019.anonymize \
    --source-manifest "$OUT/inputs/source.jsonl" \
    --unit-records "$OUT/inputs/units.jsonl" \
    --target-map "$OUT/inputs/target_map.jsonl" \
    --duration-mode pred \
    --duration-model "$DURATION_MODEL" \
    --vocoder "$model" \
    --vocoder-type nt \
    --vocoder-embeddings "$TARGET_EMBEDDINGS" \
    --out-dir "$model_out" \
    --device "$DEVICE" \
    --skip-space-check \
    --overwrite \
    2>&1 | tee "$model_out/anonymize.log"
  python - "$model_out/anon.jsonl" "$model_out/wav.scp" <<'PY'
import json
import sys
from pathlib import Path

manifest, output = map(Path, sys.argv[1:])
rows = [json.loads(line) for line in manifest.read_text(encoding="utf-8").splitlines()]
output.write_text(
    "".join(f"{row['id']} {row['audio']}\n" for row in rows),
    encoding="utf-8",
)
print(f"WROTE {output} rows={len(rows)}")
PY
done

if [[ "$RUN_MOS" == "1" ]]; then
  MOS_MODELS="$N019_OFFICIAL_MODELS/mos"
  UTMOS_CHECKPOINT="$MOS_MODELS/UTMOS22-mirror/model.ckpt"
  WHISQA_CHECKPOINT="$MOS_MODELS/WhiSQA_single_head.pt"
  WHISPER_SMALL_PATH="${N019_WHISPER_SMALL_PATH:-$HF_HOME/hub/models--openai--whisper-small/snapshots/973afd24965f72e36ca33b3055d56a652f456b4d}"
  UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"
  for required in \
    "$UTMOS_CHECKPOINT" \
    "$WHISQA_CHECKPOINT" \
    "$WHISPER_SMALL_PATH/config.json" \
    "$ROOT/vendor/UTMOS22-demo/score.py" \
    "$ROOT/vendor/WhiSQA/models/whisper_ni_predictors.py"; do
    test -f "$required" || {
      echo "Missing checkpoint-audit MOS input: $required" >&2
      exit 1
    }
  done
  export N019_WHISPER_SMALL_PATH="$WHISPER_SMALL_PATH"
  export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"
  for name in "${FOUND_MODELS[@]}"; do
    model_out="$OUT/$name"
    mkdir -p "$model_out/mos"
    python -u -m n019.eval_mos \
      --backend utmos \
      --wav-scp "$model_out/wav.scp" \
      --code-source "$ROOT/vendor/UTMOS22-demo" \
      --checkpoint "$UTMOS_CHECKPOINT" \
      --device "$DEVICE" \
      --out "$model_out/mos/UTMOS.json" \
      2>&1 | tee "$model_out/mos/UTMOS.log"
    python -u -m n019.eval_mos \
      --backend whisqa \
      --wav-scp "$model_out/wav.scp" \
      --code-source "$ROOT/vendor/WhiSQA" \
      --checkpoint "$WHISQA_CHECKPOINT" \
      --device "$DEVICE" \
      --out "$model_out/mos/WhiSQA.json" \
      2>&1 | tee "$model_out/mos/WhiSQA.log"
  done
fi

python - "$OUT" "$RUN_MOS" "${FOUND_MODELS[@]}" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
run_mos = sys.argv[2] == "1"
names = sys.argv[3:]
summary = {}
for name in names:
    meta = json.loads((out / name / "run_meta.json").read_text(encoding="utf-8"))
    entry = {
        "steps": meta.get("vocoder_version"),
        "records": meta.get("records"),
        "input_sha256": meta.get("input_sha256"),
        "anon_jsonl": str(out / name / "anon.jsonl"),
    }
    if run_mos:
        for metric in ("UTMOS", "WhiSQA"):
            report = json.loads(
                (out / name / "mos" / f"{metric}.json").read_text(encoding="utf-8")
            )
            entry[metric] = {
                "count": report["count"],
                "mean": report["mean"],
                "stddev": report["stddev"],
            }
    summary[name] = entry
(out / "summary.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(summary, indent=2, sort_keys=True))
PY

if [[ "$(id -u)" == "0" ]]; then
  chown -R "$OWNER" "$OUT"
else
  chmod -R u+rwX "$OUT"
fi
echo "VOCODER_CHECKPOINT_CPU_AUDIT_COMPLETE out=$OUT"
