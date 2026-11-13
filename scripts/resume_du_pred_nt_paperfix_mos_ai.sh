#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

SUFFIX="_n019_paperfix"
RUN_NAME="du_pred_nt_paperfix"
UTMOS_OVERLAY="$N019_VOICE_ROOT/envs/n019_utmos_overlay"
OUT="$N019_OFFICIAL_RUNS/eval/$RUN_NAME"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
ANON="$N019_OFFICIAL_DATA/anonymised/libri_test/DU-pred-nt-paperfix"

export PYTHONPATH="$UTMOS_OVERLAY:$ROOT/compat:$ROOT/src:/usr/local/"
python - <<'PY'
import fairseq
import hydra
import omegaconf
import pytorch_lightning
PY

for required in \
  "$OUT/evpc/evpc_metrics.json" \
  "$OUT/summary.json" \
  "$ANON/anon.jsonl" \
  "$VPC_ROOT/libri_test$SUFFIX/wav.scp" \
  "$ROOT/vendor/UTMOS22-demo/score.py" \
  "$ROOT/vendor/WhiSQA/checkpoints/single_head_model.pt" \
  "$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt" \
  "$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/wav2vec_small.pt"; do
  test -f "$required" || {
    echo "Missing paperfix MOS resume input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$VPC_ROOT/libri_test$SUFFIX/wav.scp")" = 1934

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
evpc = json.loads((out / "evpc" / "evpc_metrics.json").read_text())
summary = json.loads((out / "summary.json").read_text())
conditions = evpc.get("paper_conditions", {})
if not {"I", "L"}.issubset(conditions):
    raise SystemExit("Existing E-VPC metrics do not contain I and L")
if "anon" not in evpc.get("wer_percent", {}):
    raise SystemExit("Existing E-VPC metrics do not contain anonymous WER")
attacks = summary.get("attacks", {})
if not {"I", "L"}.issubset(attacks):
    raise SystemExit("Existing W-NT summary does not contain I and L")
PY

mkdir -p "$OUT/mos"
{
  echo "job=${SLURM_JOB_ID:-manual}"
  echo "host=$(hostname)"
  echo "date=$(date -Is)"
  echo "scope=resume_mos_after_completed_evpc_wnt"
  echo "suffix=$SUFFIX"
  echo "out=$OUT"
} | tee "$OUT/mos/resume_launch.txt"

N019_DATA_SUFFIX="$SUFFIX" \
N019_RUN_NAME="$RUN_NAME" \
N019_MOS_DEVICE=cuda \
  bash "$ROOT/scripts/evaluate_mos_remote.sh"

python -m n019.assemble_paper_metrics \
  --system DU-pred-nt \
  --evpc "$OUT/evpc/evpc_metrics.json" \
  --wnt-summary "$OUT/summary.json" \
  --wer-json "$OUT/evpc/evpc_metrics.json" \
  --wer-condition anon \
  --utmos "$OUT/mos/UTMOS.json" \
  --whisqa "$OUT/mos/WhiSQA.json" \
  --out "$OUT/paper_metrics.json"

python -m n019.compare_paper \
  --paper-table "$ROOT/configs/paper_table1.json" \
  --system DU-pred-nt \
  --metrics "$OUT/paper_metrics.json" \
  --out-json "$OUT/paper_comparison.json" \
  --out-md "$OUT/paper_comparison.md"

python - "$OUT" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
metrics = json.loads((out / "paper_metrics.json").read_text(encoding="utf-8"))
missing = set(metrics.get("missing", []))
if missing != {"E-VPC S", "W-NT S"}:
    raise SystemExit(
        f"Unexpected incomplete I/L/WER/MOS metric set: {sorted(missing)}"
    )
for name in ("UTMOS", "WhiSQA"):
    report = json.loads(
        (out / "mos" / f"{name}.json").read_text(encoding="utf-8")
    )
    if int(report["count"]) != 1934:
        raise SystemExit(
            f"{name} evaluated {report['count']} files, expected 1934"
        )
print("PAPERFIX_I_L_WER_MOS_COMPLETE; S_METRICS_PENDING")
PY

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
chown -R "$owner" "$OUT"
sha256sum \
  "$OUT/evpc/evpc_metrics.json" \
  "$OUT/summary.json" \
  "$OUT/mos/UTMOS.json" \
  "$OUT/mos/WhiSQA.json" \
  "$OUT/paper_metrics.json" \
  "$OUT/paper_comparison.json" \
  "$OUT/paper_comparison.md"
echo "DU_PRED_NT_PAPERFIX_MOS_RESUME_COMPLETE out=$OUT"
