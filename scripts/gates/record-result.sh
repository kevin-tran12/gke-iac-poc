#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer required}
status=${2:?status required}
mkdir -p .gate-state test-results/live
created=$(date -u +%FT%TZ)
expires=$(date -u -d "+${ENVIRONMENT_TTL_HOURS:-8} hours" +%FT%TZ)
serial=${TF_STATE_SERIAL:-0}
plan_digest=${PLAN_DIGEST:-not-applied}

jq -n \
  --argjson layer "$layer" \
  --arg status "$status" \
  --arg commit_sha "$(git rev-parse HEAD)" \
  --arg profile "${PROFILE:-core}" \
  --arg created_at "$created" \
  --arg expires_at "$expires" \
  --arg plan_digest "$plan_digest" \
  --argjson terraform_state_serial "$serial" \
  '{layer:$layer,status:$status,commit_sha:$commit_sha,profile:$profile,created_at:$created_at,expires_at:$expires_at,plan_digest:$plan_digest,terraform_state_serial:$terraform_state_serial}' \
  >".gate-state/layer-${layer}.json"
cp ".gate-state/layer-${layer}.json" "test-results/live/layer-${layer}-gate.json"

if [[ -n "${TF_STATE_BUCKET:-}" ]]; then
  gcloud storage cp ".gate-state/layer-${layer}.json" "gs://${TF_STATE_BUCKET}/gates/layer-${layer}.json" >/dev/null
fi
