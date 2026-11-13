#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"
export PYTHONPATH="$ROOT/src${PYTHONPATH:+:$PYTHONPATH}"

python "$ROOT/scripts/verify_n019_training_recipe.py"
python -m py_compile \
  "$ROOT/src/n019/vocoder.py" \
  "$ROOT/src/n019/duration.py" \
  "$ROOT/src/n019/anonymize.py" \
  "$ROOT/src/n019/diagnose_duration.py" \
  "$ROOT/src/n019/reconstruct_vocoder.py" \
  "$ROOT/src/n019/target_embedding_pooling.py" \
  "$ROOT/src/n019/rank_vocoder_snapshots.py"
for test_file in \
  "$ROOT/tests/test_hifigan.py" \
  "$ROOT/tests/test_duration.py" \
  "$ROOT/tests/test_training_recipe.py" \
  "$ROOT/tests/test_target_embedding_pooling.py" \
  "$ROOT/tests/test_rank_vocoder_snapshots.py" \
  "$ROOT/tests/test_anonymize_resume.py"; do
  python "$test_file"
done
bash -n \
  "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh" \
  "$ROOT/scripts/preflight_dcu_remote.sh" \
  "$ROOT/scripts/run_vocoder_ddp.sh" \
  "$ROOT/scripts/run_vocoder_snapshot_selection_ai.sh" \
  "$ROOT/scripts/run_target_embedding_ab_ai.sh" \
  "$ROOT/scripts/launch_vocoder_nt_2x_diag_ai.sh" \
  "$ROOT/scripts/prepare_target_speaker_mean_embeddings_remote.sh" \
  "$ROOT/scripts/prepare_vocoder_speaker_split_remote.sh" \
  "$ROOT/scripts/smoke_reconstruct_cpu_remote.sh"
echo "N019_QUALITY_FIX_VERIFY_OK root=$ROOT"
