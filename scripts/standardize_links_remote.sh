#!/usr/bin/env bash

set -euo pipefail

DATA="$HOME/voice_projects/data/n019_official"
MODELS="$HOME/voice_projects/models/n019_official"
ROOT="$HOME/voice_projects/code/n019_official"
VPC="$ROOT/vendor/Voice-Privacy-Challenge-2024"

if [[ -d "$DATA/corpora/librispeech/LibriSpeech" \
  && ! -e "$DATA/corpora/LibriSpeech" ]]; then
  ln -s "librispeech/LibriSpeech" "$DATA/corpora/LibriSpeech"
fi

if [[ -d "$DATA/corpora/libritts/LibriTTS" \
  && ! -e "$DATA/corpora/LibriTTS" ]]; then
  ln -s "libritts/LibriTTS" "$DATA/corpora/LibriTTS"
fi

if [[ -d "$MODELS/wpro" && ! -e "$MODELS/speaker_wavlm_pro" ]]; then
  ln -s "wpro" "$MODELS/speaker_wavlm_pro"
fi

mkdir -p "$DATA/vpc/exp"
for model in asv_orig asr; do
  if [[ -d "$MODELS/vpc/exp/$model" \
    && ! -e "$DATA/vpc/exp/$model" ]]; then
    ln -s "$MODELS/vpc/exp/$model" "$DATA/vpc/exp/$model"
  fi
done

if [[ ! -e "$VPC/data" ]]; then
  ln -s "$DATA/vpc/data" "$VPC/data"
fi
if [[ ! -e "$VPC/exp" ]]; then
  ln -s "$DATA/vpc/exp" "$VPC/exp"
fi

for path in \
  "$DATA/corpora/LibriSpeech" \
  "$DATA/corpora/LibriTTS" \
  "$MODELS/speaker_wavlm_pro" \
  "$VPC/data" \
  "$VPC/exp"; do
  if [[ -e "$path" ]]; then
    ls -ld "$path"
  else
    echo "PENDING $path"
  fi
done
