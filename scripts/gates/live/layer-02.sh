#!/usr/bin/env bash
set -euo pipefail
source scripts/gates/live/common.sh

gcloud compute networks describe "$(tf_output network network_name)" \
  --project "$TF_VAR_project_id" --format=json >test-results/live/network.json
gcloud compute networks subnets describe "$(tf_output network subnet_name)" \
  --project "$TF_VAR_project_id" --region "$TF_VAR_region" --format=json |
  tee test-results/live/subnet.json |
  jq -e '.privateIpGoogleAccess == true and (.secondaryIpRanges | length == 2)' >/dev/null
