#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
DATASET="libri_test_asr_n019_ext102k"
MODEL="$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local"
OLD="$N019_OFFICIAL_RUNS/eval/wer_native_cpu_shards"
OUT="$N019_OFFICIAL_RUNS/eval/wer_native_cpu_recover"

test "$(wc -l < "$VPC_ROOT/$DATASET/wav.scp")" = 1496
test "$(wc -l < "$VPC_ROOT/$DATASET/text")" = 1496
for shard in 01 02 05 06 07; do
  test -f "$OLD/shard_$shard/WER.json"
done
mkdir -p "$OUT"

export PYTHONPATH="$ROOT/src:${PYTHONPATH:-}"
pids=()
for spec in \
  "00a:0:94" "00b:94:93" \
  "03a:561:94" "03b:655:93" \
  "04a:748:94" "04b:842:93"; do
  name="${spec%%:*}"
  rest="${spec#*:}"
  offset="${rest%%:*}"
  count="${rest#*:}"
  shard_out="$OUT/$name"
  mkdir -p "$shard_out"
  N019_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
    python -u -m n019.wer_eval_hf \
      --vpc-data-root "$VPC_ROOT" \
      --dataset "$DATASET" \
      --model "$MODEL" \
      --device cpu \
      --expected-count "$count" \
      --limit "$count" \
      --offset "$offset" \
      --batch-size 8 \
      --out "$shard_out/WER.json" \
      > "$OUT/$name.log" 2>&1 &
  pids+=("$!")
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done
test "$status" = 0

python - "$OLD" "$OUT" <<'PY'
import json
import sys
from pathlib import Path

old = Path(sys.argv[1])
new = Path(sys.argv[2])
old_names = ["shard_01", "shard_02", "shard_05", "shard_06", "shard_07"]
new_names = ["00a", "00b", "03a", "03b", "04a", "04b"]
paths = [old / name for name in old_names] + [new / name for name in new_names]
errors = words = utterances = 0
hypotheses = []
for path in paths:
    result = json.loads((path / "WER.json").read_text(encoding="utf-8"))
    errors += int(result["errors"])
    words += int(result["words"])
    utterances += int(result["utterances"])
    hypotheses.extend(
        (path / "vpc_asr" / "text").read_text(encoding="utf-8").splitlines()
    )
if utterances != 1496 or len(hypotheses) != 1496:
    raise SystemExit(
        f"Expected 1496 utterances, got {utterances}/{len(hypotheses)}"
    )
wer = errors / max(1, words)
merged = {
    "backend": "vpc2024_wav2vec2_native_ctc_cpu_recovered",
    "dataset": "libri_test_asr_n019_ext102k",
    "utterances": utterances,
    "references": utterances,
    "errors": errors,
    "words": words,
    "wer": wer,
    "wer_percent": wer * 100.0,
    "completed_shards": old_names,
    "recovery_shards": new_names,
    "hypotheses": str(new / "vpc_asr" / "text"),
}
(new / "vpc_asr").mkdir(parents=True, exist_ok=True)
(new / "vpc_asr" / "text").write_text(
    "\n".join(sorted(hypotheses)) + "\n",
    encoding="utf-8",
)
(new / "WER.json").write_text(
    json.dumps(merged, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(merged, indent=2, sort_keys=True))
PY

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
chown -R "$owner" "$OUT"
sha256sum "$OUT/WER.json" "$OUT/vpc_asr/text"
echo "WER_NATIVE_CPU_RECOVER_COMPLETE out=$OUT"
