#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
DATASET="libri_test_asr_n019_ext102k"
MODEL="$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local"
OUT="${N019_WER_OUT:-$N019_OFFICIAL_RUNS/eval/wer_native_cpu_shards}"
TOTAL=1496
SHARDS="${N019_WER_SHARDS:-8}"
BASE_PER_SHARD=$((TOTAL / SHARDS))
REMAINDER=$((TOTAL % SHARDS))

test "$(wc -l < "$VPC_ROOT/$DATASET/wav.scp")" = "$TOTAL"
test "$(wc -l < "$VPC_ROOT/$DATASET/text")" = "$TOTAL"
test -f "$MODEL/config.json"
mkdir -p "$OUT"

export PYTHONPATH="$ROOT/src:${PYTHONPATH:-}"
pids=()
for index in $(seq 0 $((SHARDS - 1))); do
  if [[ "$index" -lt "$REMAINDER" ]]; then
    count=$((BASE_PER_SHARD + 1))
  else
    count="$BASE_PER_SHARD"
  fi
  offset=$((index * BASE_PER_SHARD + (index < REMAINDER ? index : REMAINDER)))
  shard_out="$OUT/shard_$(printf '%02d' "$index")"
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
      > "$OUT/shard_$(printf '%02d' "$index").log" 2>&1 &
  pids+=("$!")
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done
test "$status" = 0

python - "$OUT" "$TOTAL" "$SHARDS" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
total = int(sys.argv[2])
shards = int(sys.argv[3])
errors = 0
words = 0
utterances = 0
hypotheses = []
for index in range(shards):
    shard = root / f"shard_{index:02d}"
    result = json.loads((shard / "WER.json").read_text(encoding="utf-8"))
    errors += int(result["errors"])
    words += int(result["words"])
    utterances += int(result["utterances"])
    hypotheses.extend(
        (shard / "vpc_asr" / "text").read_text(encoding="utf-8").splitlines()
    )
if utterances != total or len(hypotheses) != total:
    raise SystemExit(
        f"Expected {total} utterances, got {utterances}/{len(hypotheses)}"
    )
merged = {
    "backend": "vpc2024_wav2vec2_native_ctc_cpu_sharded",
    "dataset": "libri_test_asr_n019_ext102k",
    "utterances": utterances,
    "references": utterances,
    "errors": errors,
    "words": words,
    "wer": errors / max(1, words),
    "wer_percent": errors / max(1, words) * 100.0,
    "shards": shards,
    "hypotheses": str(root / "vpc_asr" / "text"),
}
(root / "vpc_asr").mkdir(parents=True, exist_ok=True)
(root / "vpc_asr" / "text").write_text(
    "\n".join(sorted(hypotheses)) + "\n",
    encoding="utf-8",
)
(root / "WER.json").write_text(
    json.dumps(merged, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(merged, indent=2, sort_keys=True))
PY

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_DATA")"
chown -R "$owner" "$OUT"
sha256sum "$OUT/WER.json" "$OUT/vpc_asr/text"
echo "WER_NATIVE_CPU_SHARDS_COMPLETE out=$OUT"
