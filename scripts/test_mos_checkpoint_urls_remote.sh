#!/usr/bin/env bash

set -u

URLS=(
  "https://ghproxy.net/https://media.githubusercontent.com/media/leto19/WhiSQA/0ad007e97093aa54c0c8cdac1af3e6ad6305af3f/checkpoints/single_head_model.pt"
  "https://ghfast.top/https://media.githubusercontent.com/media/leto19/WhiSQA/0ad007e97093aa54c0c8cdac1af3e6ad6305af3f/checkpoints/single_head_model.pt"
  "https://media.githubusercontent.com/media/leto19/WhiSQA/0ad007e97093aa54c0c8cdac1af3e6ad6305af3f/checkpoints/single_head_model.pt"
)

for url in "${URLS[@]}"; do
  echo "---$url"
  curl -L -sS -I --max-time 20 "$url" \
    | grep -Ei '^(HTTP/|content-length:|content-type:|location:)' \
    | tail -8 || true
done
