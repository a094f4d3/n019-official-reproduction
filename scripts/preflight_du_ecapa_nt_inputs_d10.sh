#!/usr/bin/env bash

set -euo pipefail

ROOT="/public/home/a094f4d10/voice_projects/code/n019_official"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_VOICE_ROOT="/public/home/a094f4d10/voice_projects"
source "$ROOT/hpc/activate_n019_official.sh" >/dev/null
cd "$ROOT"

BUNDLE="$N019_OFFICIAL_DATA/processed/selection_bundles/du_nt_nt_utt_test_20261117"
TEST_RECORDS="$BUNDLE/units/unit_records.jsonl"
TEST_TARGET_MAP="$BUNDLE/target_map.jsonl"
TEST_VOCODER="$BUNDLE/assets/generator_soup2.pt"
TARGET_SAMPLE="$N019_OFFICIAL_DATA/processed/targets/target_speaker_mean32_all1158_20261117.jsonl"
LS360_MAP="$N019_OFFICIAL_DATA/processed/targets/librispeech_train_clean_360_target_map_utterance.jsonl"
NT_TARGET="/public/home/a094f4d6/voice_projects/tmp/n019_privacy_fix_20261111/target_speaker_mean32_all1158_shrink01.npz"
ECAPA_MODEL="$N019_OFFICIAL_MODELS/vpc/exp/asv_orig"
LS100_MANIFEST="/public/home/a094f4d4/voice_projects/data/n019_official/processed/manifests/librispeech_train_clean_100.jsonl"
LS100_RECORDS="/public/home/a094f4d4/voice_projects/data/n019_official/processed/units/librispeech_train_clean_100/unit_records.jsonl"
VPC_ROOT="$N019_OFFICIAL_DATA/vpc_ai/data"
OUT="$N019_OFFICIAL_RUNS/audit/du_ecapa_nt_preflight_cy20261117.json"

for required in \
  "$TEST_RECORDS" \
  "$TEST_TARGET_MAP" \
  "$TEST_VOCODER" \
  "$TARGET_SAMPLE" \
  "$LS360_MAP" \
  "$NT_TARGET" \
  "$ECAPA_MODEL/hyperparams.yaml" \
  "$ECAPA_MODEL/embedding_model.ckpt" \
  "$ECAPA_MODEL/classifier.ckpt" \
  "$LS100_MANIFEST" \
  "$LS100_RECORDS" \
  "$N019_OFFICIAL_MODELS/vpc/exp/asr_n019_local/config.json" \
  "$N019_OFFICIAL_MODELS/mos/UTMOS22-mirror/model.ckpt" \
  "$N019_OFFICIAL_MODELS/mos/WhiSQA_single_head.pt" \
  "$N019_OFFICIAL_MODELS/wpro/config.json" \
  "$N019_OFFICIAL_MODELS/wpro/model.safetensors" \
  "$N019_OFFICIAL_MODELS/wpro/spk_embeddings.py" \
  "$VPC_ROOT/data/libri_test/wav/121-121726-0000.wav" \
  "$VPC_ROOT/libri_test_n019_du_nt_nt_utt_20261117/wav.scp" \
  "$VPC_ROOT/libri_test_enrolls_n019_du_nt_nt_utt_20261117/wav.scp" \
  "$VPC_ROOT/libri_test_trials_f_n019_du_nt_nt_utt_20261117/trials" \
  "$VPC_ROOT/libri_test_trials_m_n019_du_nt_nt_utt_20261117/trials"; do
  test -s "$required" || {
    echo "Missing DU-ecapa-nt input: $required" >&2
    exit 1
  }
done

test "$(wc -l < "$TEST_RECORDS")" = 1934
test "$(find "$BUNDLE/units/codes" -maxdepth 1 -type f -name '*.npy' | wc -l)" = 1934
test "$(wc -l < "$TEST_TARGET_MAP")" = 1934
test "$(wc -l < "$TARGET_SAMPLE")" = 36560
test "$(wc -l < "$LS360_MAP")" = 104014
test "$(wc -l < "$LS100_MANIFEST")" = 28539
test "$(wc -l < "$LS100_RECORDS")" = 28539
test "$(find "$VPC_ROOT/data/libri_test/wav" -maxdepth 1 -type f -name '*.wav' | wc -l)" = 1934
test "$(sha256sum "$TEST_VOCODER" | awk '{print $1}')" = \
  "ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6"

mkdir -p "$(dirname "$OUT")"
python - "$TEST_TARGET_MAP" "$LS360_MAP" "$TARGET_SAMPLE" \
  "$NT_TARGET" "$TEST_RECORDS" "$OUT" <<'PY'
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

import numpy as np

test_map, ls360_map, target_sample, nt_target, test_records, out = map(
    Path, sys.argv[1:]
)

def rows(path: Path):
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                yield json.loads(line)

test_speakers = {str(row["target_speaker"]) for row in rows(test_map)}
ls360_speakers = {str(row["target_speaker"]) for row in rows(ls360_map)}
all_required = test_speakers | ls360_speakers
groups = Counter(str(row["speaker"]) for row in rows(target_sample))
missing = sorted(all_required - set(groups))
if missing:
    raise SystemExit(f"Target sample missing speakers: {missing[:10]}")
if len(groups) != 1158:
    raise SystemExit(f"Expected 1158 target speakers, got {len(groups)}")
if len(test_speakers) != 843:
    raise SystemExit(f"Expected 843 test target speakers, got {len(test_speakers)}")
if len(ls360_speakers) != 1158:
    raise SystemExit(f"Expected 1158 LS360 target speakers, got {len(ls360_speakers)}")

archive = np.load(nt_target, allow_pickle=False)
try:
    nt_keys = set(archive.files)
    missing_nt = sorted(test_speakers - nt_keys)
    if missing_nt:
        raise SystemExit(f"NT target NPZ missing test speakers: {missing_nt[:10]}")
    if any(archive[key].shape != (250,) for key in nt_keys):
        raise SystemExit("NT target NPZ has non-250-D vectors")
finally:
    archive.close()

record_count = sum(1 for _ in rows(test_records))
if record_count != 1934:
    raise SystemExit(f"Expected 1934 test records, got {record_count}")

def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

summary = {
    "status": "ok",
    "test_records": record_count,
    "test_target_speakers": len(test_speakers),
    "ls360_target_rows": sum(1 for _ in rows(ls360_map)),
    "ls360_target_speakers": len(ls360_speakers),
    "required_target_speakers": len(all_required),
    "target_sample_speakers": len(groups),
    "target_sample_group_min": min(groups.values()),
    "target_sample_group_mean": sum(groups.values()) / len(groups),
    "target_sample_group_max": max(groups.values()),
    "nt_target_keys": len(nt_keys),
    "inputs": {
        "test_target_map_sha256": sha(test_map),
        "ls360_target_map_sha256": sha(ls360_map),
        "target_sample_sha256": sha(target_sample),
        "nt_target_sha256": sha(nt_target),
    },
}
out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2, sort_keys=True))
PY

sha256sum "$OUT"
echo "DU_ECAPA_NT_PREFLIGHT_COMPLETE out=$OUT"
