#!/usr/bin/env bash
set -euo pipefail

: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
mkdir -p .gate-state test-results/live
lease=.gate-state/environment-lease.json
remote="gs://${TF_STATE_BUCKET}/gates/environment-lease.json"

if [[ ! -s $lease ]]; then
  gcloud storage cp "$remote" "$lease" >/dev/null 2>&1 || true
fi

create_new=false
if [[ -s $lease ]]; then
  jq -e '.schema_version == 1 and .expires_at and .created_at and .status' "$lease" >/dev/null
  if [[ $(jq -r .status "$lease") != active ]]; then
    create_new=true
  else
    expires_epoch=$(date -u -d "$(jq -r .expires_at "$lease")" +%s)
    (( expires_epoch > $(date -u +%s) )) || {
      printf 'The existing lab lease expired. Run runtime teardown before starting another apply.\n' >&2
      exit 1
    }
  fi
else
  create_new=true
fi

if [[ $create_new == true ]]; then
  created=$(date -u +%FT%TZ)
  expires=$(date -u -d "+${ENVIRONMENT_TTL_HOURS:-4} hours" +%FT%TZ)
  jq -n \
    --arg created_at "$created" \
    --arg expires_at "$expires" \
    --arg commit_sha "$(git rev-parse HEAD)" \
    '{schema_version:1,created_at:$created_at,expires_at:$expires_at,commit_sha:$commit_sha,status:"active"}' \
    >"$lease"
  gcloud storage cp "$lease" "$remote" >/dev/null
fi

cp "$lease" test-results/live/environment-lease.json
printf 'Lab lease expires at %s. Later layers do not extend it.\n' "$(jq -r .expires_at "$lease")"
