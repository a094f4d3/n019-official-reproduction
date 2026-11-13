#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export N019_DURATION_EMBEDDING_KIND=pred
export N019_DURATION_RUN_NAME=duration_pred_paperfix
exec bash "$ROOT/scripts/run_duration_ai.sh"
