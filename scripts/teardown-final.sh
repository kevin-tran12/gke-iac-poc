#!/usr/bin/env bash
set -euo pipefail

: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
: "${TF_VAR_project_id:?TF_VAR_project_id is required}"
bash scripts/verify-no-billable-resources.sh

gcloud storage rm --recursive "gs://${TF_STATE_BUCKET}/**" 2>/dev/null || true
gcloud storage buckets delete "gs://${TF_STATE_BUCKET}" --quiet
gcloud billing projects unlink "$TF_VAR_project_id" --quiet
gcloud projects delete "$TF_VAR_project_id" --quiet
printf 'Project %s was unlinked from billing and submitted for deletion.\n' "$TF_VAR_project_id"
