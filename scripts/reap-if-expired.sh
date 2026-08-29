#!/usr/bin/env bash
set -euo pipefail

: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
mkdir -p .gate-state
mapfile -t records < <(gcloud storage ls "gs://${TF_STATE_BUCKET}/gates/layer-*.json" 2>/dev/null | sort -V)
(( ${#records[@]} > 0 )) || { printf 'No live gate records; nothing to reap.\n'; exit 0; }
latest=${records[-1]}
gcloud storage cp "$latest" .gate-state/reaper.json >/dev/null
expires=$(jq -r .expires_at .gate-state/reaper.json)
expires_epoch=$(date -u -d "$expires" +%s)
now_epoch=$(date -u +%s)
if (( expires_epoch <= now_epoch )); then
  printf 'Environment expired at %s; starting reverse-order teardown.\n' "$expires"
  bash scripts/teardown-runtime.sh
else
  printf 'Environment remains valid until %s.\n' "$expires"
fi
