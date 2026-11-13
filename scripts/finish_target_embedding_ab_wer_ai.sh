#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

OUT="${N019_TARGET_AB_OUT:?Set N019_TARGET_AB_OUT}"
ASR_MODEL="${N019_TARGET_AB_ASR_MODEL:-$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local}"

for variant in utterance speaker_mean_l2; do
  root="$OUT/$variant"
  test "$(find "$root/anonymised" -maxdepth 1 -type f -name '*.wav' | wc -l)" = 100
  test -f "$root/mos/UTMOS.json"
  test -f "$root/mos/WhiSQA.json"
done
test -f "$OUT/utterance/WER.json"

if [[ ! -f "$OUT/speaker_mean_l2/WER.json" ]]; then
  python -u -m n019.wer_eval_vpc \
    --vpc-data-root "$OUT/speaker_mean_l2/vpc/data" \
    --dataset selection \
    --model "$ASR_MODEL" \
    --device cuda \
    --expected-count 100 \
    --out "$OUT/speaker_mean_l2/WER.json" \
    2>&1 | tee "$OUT/speaker_mean_l2/wer.log"
fi

python - "$OUT" <<'PY'
import json
import statistics
import sys
from pathlib import Path

root = Path(sys.argv[1])


def load(name):
    base = root / name
    return {
        "UTMOS": json.loads((base / "mos/UTMOS.json").read_text(encoding="utf-8")),
        "WhiSQA": json.loads((base / "mos/WhiSQA.json").read_text(encoding="utf-8")),
        "WER": json.loads((base / "WER.json").read_text(encoding="utf-8")),
    }


utterance = load("utterance")
speaker = load("speaker_mean_l2")
count = int(utterance["UTMOS"]["count"])
if count != 100:
    raise SystemExit(f"Expected 100 utterances, got {count}")
for variant in (utterance, speaker):
    if any(
        int(variant[name]["count" if name != "WER" else "utterances"]) != count
        for name in ("UTMOS", "WhiSQA", "WER")
    ):
        raise SystemExit(f"Count mismatch in {variant}")

result = {
    "system": "target-embedding-pooling-ab",
    "count": count,
    "utterance": {
        "UTMOS": float(utterance["UTMOS"]["mean"]),
        "WhiSQA": float(utterance["WhiSQA"]["mean"]),
        "WER_percent": float(utterance["WER"]["wer_percent"]),
    },
    "speaker_mean_l2": {
        "UTMOS": float(speaker["UTMOS"]["mean"]),
        "WhiSQA": float(speaker["WhiSQA"]["mean"]),
        "WER_percent": float(speaker["WER"]["wer_percent"]),
    },
}
for metric in ("UTMOS", "WhiSQA", "WER_percent"):
    result[f"delta_{metric}"] = (
        result["speaker_mean_l2"][metric] - result["utterance"][metric]
    )
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
    result[f"{metric}_paired_delta_mean"] = statistics.fmean(deltas)
    result[f"{metric}_paired_delta_stderr"] = (
        statistics.stdev(deltas) / (len(deltas) ** 0.5)
    )

(root / "comparison.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
(root / "comparison.md").write_text(
    "# Target Embedding Pooling A/B\n\n"
    f"- Utterance: UTMOS {result['utterance']['UTMOS']:.6f}, "
    f"WhiSQA {result['utterance']['WhiSQA']:.6f}, "
    f"WER {result['utterance']['WER_percent']:.6f}%\n"
    f"- Speaker mean L2: UTMOS {result['speaker_mean_l2']['UTMOS']:.6f}, "
    f"WhiSQA {result['speaker_mean_l2']['WhiSQA']:.6f}, "
    f"WER {result['speaker_mean_l2']['WER_percent']:.6f}%\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

owner="$(stat -c '%u:%g' "$N019_OFFICIAL_RUNS")"
chown -R "$owner" "$OUT"
sha256sum "$OUT/comparison.json" "$OUT/comparison.md" |
  tee "$OUT/SHA256SUMS.txt"
echo "N019_TARGET_EMBEDDING_AB_WER_COMPLETE out=$OUT"
