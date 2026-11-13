#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export N019_VOCODER_TYPE=ecapa
exec bash "$ROOT/scripts/run_vocoder_ddp_pilot_ai.sh"
