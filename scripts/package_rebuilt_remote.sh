#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
BUILD_ID="VPC2024_LibriSpeech_rebuilt_v1"
STAGING="$DATA/rebuilt/$BUILD_ID"
ARCHIVE="$DATA/rebuilt/$BUILD_ID.tar.zst"

mkdir -p "$STAGING/data" "$STAGING/audit"

for path in "$DATA"/vpc/data/libri_dev_* "$DATA"/vpc/data/libri_test_*; do
  name=$(basename "$path")
  if [[ -d "$path" && ! -e "$STAGING/data/$name" ]]; then
    cp -al "$path" "$STAGING/data/$name"
  fi
done

for name in libri_dev libri_test; do
  path="$DATA/vpc/data/$name"
  if [[ -d "$path" && ! -e "$STAGING/data/$name" ]]; then
    cp -al "$path" "$STAGING/data/$name"
  fi
done

rsync -a "$ROOT/audit/materialize_full/" "$STAGING/audit/materialize_full/"
cp -f "$ROOT/audit/bootstrap_zip_sha256.txt" "$STAGING/audit/"
cp -f "$ROOT/audit/librispeech_dev_test_extract.txt" "$STAGING/audit/"

cat > "$STAGING/audit/build_id.txt" <<EOF
$BUILD_ID
EOF

cat > "$STAGING/audit/build_notes.txt" <<'EOF'
Source audio:
  LibriSpeech dev-clean.tar.gz, MD5 42e2234ba48799c1f50f24a7926300a1
  LibriSpeech test-clean.tar.gz, MD5 32fa31d27d2e1cad72775fee3f4849a9

Selection:
  Official VPC2024 data.zip wav.scp manifests only.
  Dev and test utterances are materialized independently.

Conversion:
  16 kHz mono PCM16 WAV via FFmpeg.

Scope:
  This is a protocol-based reconstruction for VPC2024 libri_dev/libri_test.
  It is not claimed to be byte-identical to the registered organizer archive.
EOF

(
  cd "$STAGING"
  find data -type f -name '*.wav' -print0 \
    | sort -z \
    | xargs -0 sha256sum \
    > SHA256SUMS
)

if [[ -f "$ARCHIVE" ]]; then
  mv "$ARCHIVE" "$ARCHIVE.invalid.$(date +%Y%m%d_%H%M%S)"
  rm -f "$ARCHIVE.sha256"
fi

tar -I 'zstd -T0 -12' -cf "$ARCHIVE.part" -C "$DATA/rebuilt" "$BUILD_ID"
mv "$ARCHIVE.part" "$ARCHIVE"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"

echo "PACKAGE_OK $ARCHIVE"
cat "$ARCHIVE.sha256"
