#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/voice_projects/code/n019_official"
DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
AUDIT="$ROOT/audit"

test "$(stat -c '%s' "$MODELS/wpro/model.safetensors")" = "1266588504"
test "$(stat -c '%s' "$MODELS/hubert/pytorch_model.bin")" = "377569754"
test "$(stat -c '%s' "$MODELS/vpc/asr.zip")" = "752987942"

wnt_sha=$(sha256sum "$MODELS/wpro/model.safetensors" | awk '{print $1}')
test "$wnt_sha" = "ad40a04ae6f0b46dbe6c7a6db71ff46f99775c59a0dccf61eb91f29216fbb2d4"

hubert_sha=$(sha256sum "$MODELS/hubert/pytorch_model.bin" | awk '{print $1}')
asr_sha=$(sha256sum "$MODELS/vpc/asr.zip" | awk '{print $1}')
asv_sha=$(sha256sum "$MODELS/vpc/asv_orig.zip" | awk '{print $1}')
data_sha=$(sha256sum "$DATA/vpc/data.zip" | awk '{print $1}')
package_sha=$(sha256sum \
  "$DATA/rebuilt/VPC2024_LibriSpeech_rebuilt_v1.tar.zst" \
  | awk '{print $1}')

cat > "$AUDIT/asset_manifest.tsv" <<EOF
asset	path	size	sha256_or_md5
VPC commit	$ROOT/vendor/Voice-Privacy-Challenge-2024	-	$(git -C "$ROOT/vendor/Voice-Privacy-Challenge-2024" rev-parse HEAD)
data.zip	$DATA/vpc/data.zip	$(stat -c '%s' "$DATA/vpc/data.zip")	$data_sha
asv_orig.zip	$MODELS/vpc/asv_orig.zip	$(stat -c '%s' "$MODELS/vpc/asv_orig.zip")	$asv_sha
asr.zip	$MODELS/vpc/asr.zip	$(stat -c '%s' "$MODELS/vpc/asr.zip")	$asr_sha
HuBERT model	$MODELS/hubert/pytorch_model.bin	$(stat -c '%s' "$MODELS/hubert/pytorch_model.bin")	$hubert_sha
W-NT model	$MODELS/wpro/model.safetensors	$(stat -c '%s' "$MODELS/wpro/model.safetensors")	$wnt_sha
rebuilt package	$DATA/rebuilt/VPC2024_LibriSpeech_rebuilt_v1.tar.zst	$(stat -c '%s' "$DATA/rebuilt/VPC2024_LibriSpeech_rebuilt_v1.tar.zst")	$package_sha
EOF

cat "$AUDIT/asset_manifest.tsv"
