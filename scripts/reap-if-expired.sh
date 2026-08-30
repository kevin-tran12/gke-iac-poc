#!/usr/bin/env bash
set -euo pipefail

: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
mkdir -p .gate-state
remote="gs://${TF_STATE_BUCKET}/gates/environment-lease.json"
lease=.gate-state/environment-lease.json
if ! gcloud storage cp "$remote" "$lease" >/dev/null 2>&1; then
  printf 'No active environment lease; nothing to reap.\n'
  exit 0
fi

jq -e '.schema_version == 1 and .status == "active" and .expires_at' "$lease" >/dev/null
expires=$(jq -r .expires_at "$lease")
expires_epoch=$(date -u -d "$expires" +%s)
now_epoch=$(date -u +%s)
if (( expires_epoch <= now_epoch )); then
  printf 'Environment lease expired at %s; starting reverse-order teardown.\n' "$expires"
  bash scripts/teardown-runtime.sh
else
  printf 'Environment lease remains valid until %s. Later gate runs cannot extend it.\n' "$expires"
fi
