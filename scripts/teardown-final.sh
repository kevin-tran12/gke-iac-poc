#!/usr/bin/env bash
set -euo pipefail

: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
: "${TF_VAR_project_id:?TF_VAR_project_id is required}"
: "${CONFIRM_FINAL_DELETE:?CONFIRM_FINAL_DELETE must equal the exact project ID}"
test "$CONFIRM_FINAL_DELETE" = "$TF_VAR_project_id" || {
  printf 'final deletion confirmation does not match project %s\n' "$TF_VAR_project_id" >&2
  exit 2
}
bash scripts/verify-no-billable-resources.sh

mkdir -p test-results
gcloud projects describe "$TF_VAR_project_id" --format=json >test-results/final-project-before-delete.json
gcloud billing projects describe "$TF_VAR_project_id" --format=json >test-results/final-billing-before-delete.json
gcloud storage rm --recursive "gs://${TF_STATE_BUCKET}/**" 2>/dev/null || true
gcloud storage buckets delete "gs://${TF_STATE_BUCKET}" --quiet
gcloud billing projects unlink "$TF_VAR_project_id" --quiet
gcloud projects delete "$TF_VAR_project_id" --quiet
printf 'Project %s was unlinked from billing and submitted for deletion.\n' "$TF_VAR_project_id"
