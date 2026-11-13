#!/usr/bin/env bash

set -euo pipefail

ACCOUNT=$(id -un)
if [[ "$ACCOUNT" != "a094f4d4" ]]; then
  echo "This extraction job is restricted to a094f4d4" >&2
  exit 2
fi

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
AUDIT="$ROOT/audit"
JOB_ID=${SLURM_JOB_ID:-manual}
STAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$AUDIT"

echo "extract_begin account=$ACCOUNT host=$(hostname) date=$(date -Is) job=$JOB_ID"
df -h "$HOME"
free -h || true

check_archive_md5() {
  local path=$1
  local expected=$2
  test -s "$path"
  local actual
  actual=$(md5sum "$path" | awk '{print $1}')
  test "$actual" = "$expected"
  echo "MD5_OK $path $actual"
}

extract_other500() {
  local archive="$DATA/corpora/libritts/train-other-500.tar.gz"
  local base="$DATA/corpora/libritts"
  local canonical="$base/LibriTTS/train-other-500"
  local stage="$base/.train-other-500.extract.$JOB_ID"
  local index="$AUDIT/train-other-500.index.$JOB_ID.txt"
  local log="$AUDIT/train-other-500.extract.$JOB_ID.txt"

  check_archive_md5 "$archive" 7b181dd5ace343a5f38427999684aa6f
  test ! -e "$stage"
  mkdir -p "$stage"

  echo "OTHER500_EXTRACT_START $(date -Is)"
  if command -v pigz >/dev/null 2>&1; then
    pigz -dc -p "${SLURM_CPUS_PER_TASK:-16}" "$archive" \
      | tar -xf - -C "$stage" --index-file "$index" \
          --checkpoint=10000 --checkpoint-action=echo
  else
    gzip -dc "$archive" \
      | tar -xf - -C "$stage" --index-file "$index" \
          --checkpoint=10000 --checkpoint-action=echo
  fi

  test -d "$stage/LibriTTS/train-other-500"
  local listed
  local extracted
  listed=$(grep -c '\.wav$' "$index")
  extracted=$(find "$stage/LibriTTS/train-other-500" -type f -name '*.wav' \
    -printf '.' | wc -c)
  test "$listed" -gt 0
  test "$listed" = "$extracted"

  if [[ -e "$canonical" ]]; then
    mv "$canonical" "$canonical.partial.$STAMP"
  fi
  mv "$stage/LibriTTS/train-other-500" "$canonical"
  rmdir "$stage/LibriTTS" 2>/dev/null || true
  rmdir "$stage" 2>/dev/null || true

  {
    echo "archive=$archive"
    echo "archive_md5=7b181dd5ace343a5f38427999684aa6f"
    echo "target=$canonical"
    echo "listed_wav=$listed"
    echo "extracted_wav=$extracted"
    echo "completed_at=$(date -Is)"
  } > "$log"
  echo "OTHER500_EXTRACT_DONE wav=$extracted"
}

extract_rebuilt() {
  local archive="$DATA/rebuilt/VPC2024_LibriSpeech_rebuilt_v1.tar.zst"
  local destination="$DATA/rebuilt/VPC2024_LibriSpeech_rebuilt_v1"
  local stage="$DATA/rebuilt/.VPC2024_LibriSpeech_rebuilt_v1.extract.$JOB_ID"

  test -s "$archive"
  local actual_sha
  actual_sha=$(sha256sum "$archive" | awk '{print $1}')
  test "$actual_sha" = \
    5c446fefe41e58fc749f5cc6e2931d858de2e58a73e4feb74c4a721ec7fad217
  echo "SHA256_OK $archive $actual_sha"

  if [[ -e "$destination" ]]; then
    echo "REBUILT_ALREADY_PRESENT $destination"
    return 0
  fi

  test ! -e "$stage"
  mkdir -p "$stage"
  tar --zstd -xf "$archive" -C "$stage"

  local wav_count
  wav_count=$(find "$stage" -type f -name '*.wav' | wc -l)
  test "$wav_count" = "4255"
  mv "$stage" "$destination"
  echo "REBUILT_EXTRACT_DONE wav=$wav_count"
}

extract_vpc_archives() {
  local archive
  for archive in \
    "$DATA/vpc/data.zip" \
    "$DATA/vpc/data_test_tools.zip"; do
    test -s "$archive"
    unzip -t "$archive" >/dev/null
  done
  if [[ ! -d "$DATA/vpc/data" ]]; then
    unzip -q "$DATA/vpc/data.zip" -d "$DATA/vpc"
  fi
  if [[ ! -d "$DATA/vpc/data_test_tools" ]]; then
    unzip -q "$DATA/vpc/data_test_tools.zip" -d "$DATA/vpc"
  fi

  test -s "$MODELS/vpc/asv_orig.zip"
  test -s "$MODELS/vpc/asr.zip"
  unzip -t "$MODELS/vpc/asv_orig.zip" >/dev/null
  unzip -t "$MODELS/vpc/asr.zip" >/dev/null
  if [[ ! -d "$MODELS/vpc/exp/asv_orig" ]]; then
    unzip -q "$MODELS/vpc/asv_orig.zip" -d "$MODELS/vpc"
  fi
  if [[ ! -d "$MODELS/vpc/exp/asr" ]]; then
    unzip -q "$MODELS/vpc/asr.zip" -d "$MODELS/vpc"
  fi
  echo "VPC_ARCHIVES_OK"
}

extract_vpc_archives
extract_rebuilt
extract_other500

{
  echo "account=$ACCOUNT"
  echo "job_id=$JOB_ID"
  echo "date=$(date -Is)"
  echo "train_other_500=$(find "$DATA/corpora/libritts/LibriTTS/train-other-500" -type f -name '*.wav' | wc -l)"
  echo "rebuilt_wav=$(find "$DATA/rebuilt/VPC2024_LibriSpeech_rebuilt_v1" -type f -name '*.wav' | wc -l)"
  echo "vpc_data_manifest_lines=$(wc -l < "$DATA/vpc/data/libri_test_enrolls/wav.scp")"
} | tee "$AUDIT/extract_all_$JOB_ID.txt"

echo "extract_complete $(date -Is)"
