#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer required}
profile=${2:-core}
if [[ "${APPLY:-false}" == true ]]; then
  printf 'APPLY=true is no longer supported. Plan, review, apply, and verify explicitly.\n' >&2
  exit 2
fi
printf 'run-layer.sh is plan-only for compatibility.\n' >&2
exec bash scripts/gates/plan-layer.sh "$layer" "$profile"
