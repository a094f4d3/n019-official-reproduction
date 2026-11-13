#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
AUDIT="$ROOT/audit"

source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

bash scripts/standardize_links_remote.sh

test -d "$DATA/corpora/LibriSpeech/train-clean-100"
test -d "$DATA/corpora/LibriSpeech/train-clean-360"
test -d "$DATA/corpora/LibriTTS/train-clean-100"
test -f "$DATA/corpora/libritts/train-other-500.tar.gz"

grep -q "2a93770f6d5c6c964bc36631d331a522" \
  "$HOME/voice_projects/logs/n019_official/training_extract.log"
grep -q "c0e676e450a7ff2f54aeade5171606fa" \
  "$HOME/voice_projects/logs/n019_official/training_extract.log"
grep -q "4a8c202b78fe1bc0c47916a98f3a2ea8" \
  "$HOME/voice_projects/logs/n019_official/training_extract.log"
grep -q "7b181dd5ace343a5f38427999684aa6f" \
  "$HOME/voice_projects/logs/n019_official/training_extract.log"

python scripts/verify_vpc_rebuild.py \
  --vpc-root "$DATA/vpc" \
  --output "$AUDIT/materialize_full/verification.json" \
  >/dev/null

sha256sum -c "$DATA/rebuilt/VPC2024_LibriSpeech_rebuilt_v1.tar.zst.sha256"

python -m unittest discover -s tests -v \
  > "$AUDIT/unit_tests.txt" 2>&1

bash scripts/record_environment_remote.sh

librispeech_train100=$(find \
  "$DATA/corpora/LibriSpeech/train-clean-100" -type f -name '*.flac' | wc -l)
librispeech_train360=$(find \
  "$DATA/corpora/LibriSpeech/train-clean-360" -type f -name '*.flac' | wc -l)
libritts_clean100=$(find \
  "$DATA/corpora/LibriTTS/train-clean-100" -type f -name '*.wav' | wc -l)
libritts_other500=0
if [[ -d "$DATA/corpora/LibriTTS/train-other-500" ]]; then
  libritts_other500=$(find \
    "$DATA/corpora/LibriTTS/train-other-500" -type f -name '*.wav' | wc -l)
fi

cat > "$AUDIT/PRIMARY_SETUP_STATUS" <<EOF
checked_at=$(date -Is)
account=a094f4d4
mode=HPC_login_node_zero_card
project_root=$ROOT
data_root=$DATA
model_root=$MODELS
vpc_repo_commit=$(git -C vendor/Voice-Privacy-Challenge-2024 rev-parse HEAD)
librispeech_train_clean_100_flac=$librispeech_train100
librispeech_train_clean_360_flac=$librispeech_train360
libritts_train_clean_100_wav=$libritts_clean100
libritts_train_other_500_wav=$libritts_other500
libritts_train_other_500_archive=$DATA/corpora/libritts/train-other-500.tar.gz
libritts_train_other_500_archive_md5=7b181dd5ace343a5f38427999684aa6f
libritts_train_other_500_extract_status=partial_pending_platform_small_file_limit
rebuilt_package=$DATA/rebuilt/VPC2024_LibriSpeech_rebuilt_v1.tar.zst
rebuilt_package_sha256=$(sha256sum \
  "$DATA/rebuilt/VPC2024_LibriSpeech_rebuilt_v1.tar.zst" | awk '{print $1}')
cpu_probe=$AUDIT/cpu_probe.json
unit_tests=$AUDIT/unit_tests.txt
environment=$AUDIT/environment.txt
EOF

cat "$AUDIT/PRIMARY_SETUP_STATUS"
