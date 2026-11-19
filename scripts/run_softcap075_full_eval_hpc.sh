#!/usr/bin/env bash

set -euo pipefail

ROOT=/public/home/a094f4d10/voice_projects/code/n019_official
VOICE_ROOT=/public/home/a094f4d10/voice_projects
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="$VOICE_ROOT"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

OUT="$VOICE_ROOT/runs/n019_official/softcap075_recovery_20261119"
ANON_OUT="$OUT/anonymised"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc/data"
SUFFIX=_n019_softcap075_recovery_20261119
VOCODER="$VOICE_ROOT/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117/assets/generator_soup2.pt"
TARGET_EMBEDDINGS="$VOICE_ROOT/data/n019_official/processed/embeddings/nt_ecapa_residual_test_20261117/residual_0p5.npz"
DURATION_MODEL=/public/home/a094f4d6/voice_projects/runs/n019_official/duration_pred_paperfix/best.pt
VOCODER_SHA=ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6
TARGET_EMBEDDINGS_SHA=7a015304bebdcd12bcb4deda5792ea1941159650eff4c97367716b0748e690ef
DURATION_SHA=8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c

test "$(sha256sum "$VOCODER" | awk '{print $1}')" = "$VOCODER_SHA"
test "$(sha256sum "$TARGET_EMBEDDINGS" | awk '{print $1}')" = "$TARGET_EMBEDDINGS_SHA"
test "$(sha256sum "$DURATION_MODEL" | awk '{print $1}')" = "$DURATION_SHA"
test "$(wc -l < "$ANON_OUT/anon.jsonl")" = 1934
test "$(find "$ANON_OUT" -maxdepth 1 -type f -name '*.wav' | wc -l)" = 1934
test "$(wc -l < "$VPC_ROOT/libri_test$SUFFIX/wav.scp")" = 1934

export N019_EVAL_LABEL=softcap075_recovery_20261119
export N019_EVAL_SYSTEM=DU-pred-nt-residual05-durextra05-softcap075
export N019_EVAL_STEPS=96000
export N019_EVAL_VOCODER="$VOCODER"
export N019_EVAL_VOC_SHA="$VOCODER_SHA"
export N019_EVAL_TARGET_EMBEDDINGS="$TARGET_EMBEDDINGS"
export N019_EVAL_TARGET_EMBEDDING_KEY=target_speaker
export N019_EVAL_TARGET_EMBEDDING_MODE=speaker_mean_l2
export N019_EVAL_DURATION_MODE=pred
export N019_EVAL_DURATION_MODEL="$DURATION_MODEL"
export N019_EVAL_ANON_OUT="$ANON_OUT"
export N019_EVAL_VPC_DATA="$VPC_ROOT"
export N019_EVAL_OUT="$OUT/quality"
bash "$ROOT/scripts/run_full_eval_param_ai.sh"

export N019_DATA_SUFFIX="$SUFFIX"
export N019_VPC_DATA="$VPC_ROOT"
export N019_WNT_BASE_VPC_DATA="$VPC_ROOT"
export N019_WNT_ATTACKS=L
export N019_WNT_MODEL="$N019_OFFICIAL_MODELS/wpro"
export N019_WNT_OUT="$OUT/wnt_l"
bash "$ROOT/scripts/evaluate_wnt_remote.sh"

python - "$OUT" "$ANON_OUT/anon.jsonl" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
anon = Path(sys.argv[2])
quality = json.loads((out / "quality" / "quality_metrics.json").read_text(encoding="utf-8"))
wnt = json.loads((out / "wnt_l" / "summary.json").read_text(encoding="utf-8"))
result = {
    "duration_soft_cap_frames": 0.75,
    "duration_extrapolation": 0.5,
    "preserve_predicted_total": True,
    "anon_jsonl_sha256": hashlib.sha256(anon.read_bytes()).hexdigest(),
    "quality": quality["values"],
    "wnt_L": wnt["attacks"]["L"],
}
(out / "summary.json").write_text(
    json.dumps(result, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps(result, indent=2, sort_keys=True))
PY

sha256sum "$OUT/summary.json" "$OUT/quality/quality_metrics.json" "$OUT/wnt_l/summary.json" "$ANON_OUT/anon.jsonl"
echo N019_SOFTCAP075_FULL_EVAL_COMPLETE
