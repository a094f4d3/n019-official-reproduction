#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export N019_DURATION_EMBEDDING_KIND=ecapa
exec bash "$ROOT/scripts/run_duration_ai.sh"
