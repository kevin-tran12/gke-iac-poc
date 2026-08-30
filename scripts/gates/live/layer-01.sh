#!/usr/bin/env bash
set -euo pipefail
source scripts/gates/live/common.sh

project=$(tf_output bootstrap project_id)
bucket=$(tf_output bootstrap state_bucket)
plan_sa=$(tf_output bootstrap terraform_plan_service_account)
apply_sa=$(tf_output bootstrap terraform_apply_service_account)
test "$project" = "$TF_VAR_project_id"
gcloud projects describe "$project" --format=json |
  tee test-results/live/bootstrap-project.json | jq -e '.lifecycleState == "ACTIVE"' >/dev/null
gcloud services list --project "$project" --enabled --format='value(config.name)' |
  tee test-results/live/bootstrap-services.txt | grep -Fxq billingbudgets.googleapis.com
gcloud storage buckets describe "gs://${bucket}" --format=json |
  tee test-results/live/bootstrap-state-bucket.json |
  jq -e '.uniform_bucket_level_access == true and .public_access_prevention == "enforced"' >/dev/null
gcloud iam workload-identity-pools providers describe github \
  --project "$project" --location global --workload-identity-pool github-actions --format=json \
  >test-results/live/bootstrap-wif-provider.json
for service_account in "$plan_sa" "$apply_sa"; do
  test -z "$(gcloud iam service-accounts keys list --iam-account "$service_account" --managed-by=user --format='value(name)')"
done
