#!/usr/bin/env bash
set -euo pipefail
: "${TF_VAR_project_id:?project required}"
: "${REGION:=us-central1}"
: "${BAD_IMAGE:?digest of deliberately unhealthy signed test image required}"

release="failure-$(date -u +%Y%m%d%H%M%S)"
gcloud deploy releases create "$release" --project "$TF_VAR_project_id" --region "$REGION" --delivery-pipeline gke-lab \
  --images="gke-lab-api=$BAD_IMAGE" --skaffold-file deploy/skaffold.yaml
rollout=$(gcloud deploy rollouts list --project "$TF_VAR_project_id" --region "$REGION" --delivery-pipeline gke-lab --release "$release" --format='value(name)' --limit=1)
gcloud deploy rollouts describe "$rollout" --project "$TF_VAR_project_id" --region "$REGION" --delivery-pipeline gke-lab --release "$release" --format=json |
  jq -e '.state == "FAILED" or .state == "HALTED"' >/dev/null
