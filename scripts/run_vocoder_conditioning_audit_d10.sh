#!/bin/bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

python scripts/audit_vocoder_speaker_conditioning.py \
  --checkpoint /public/home/a094f4d6/voice_projects/tmp/n019_privacy_fix_20261111/generator_soup2.pt \
  --out "$N019_OFFICIAL_RUNS/audit/vocoder_speaker_conditioning_formal_soup2_20261117.json"
