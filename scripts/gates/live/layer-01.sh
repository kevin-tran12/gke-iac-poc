#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # Project-root path is intentional for gate execution.
source scripts/gates/live/common.sh

expected_project=${TF_VAR_project_id:?TF_VAR_project_id is required}
project=$(tf_output bootstrap project_id)
bucket=$(tf_output bootstrap state_bucket)
budget_name=$(tf_output bootstrap budget_name)
phase_accounts=$(terraform -chdir=terraform/bootstrap output -json terraform_phase_service_accounts)
expected_services=$(terraform -chdir=terraform/bootstrap output -json enabled_service_catalog | jq -r 'keys[]')
project_resource="//cloudresourcemanager.googleapis.com/projects/${project}"

test "$project" = "$expected_project"
mkdir -p test-results/live/iam-troubleshooter

gcloud projects describe "$project" --format=json |
  tee test-results/live/bootstrap-project.json | jq -e '.lifecycleState == "ACTIVE"' >/dev/null
gcloud billing projects describe "$project" --format=json |
  tee test-results/live/bootstrap-billing.json | jq -e '.billingEnabled == true' >/dev/null
gcloud billing budgets describe "$budget_name" --format=json |
  tee test-results/live/bootstrap-budget.json | jq -e '.amount.specifiedAmount.currencyCode == "USD"' >/dev/null

gcloud services list --project "$project" --enabled --format='value(config.name)' |
  tee test-results/live/bootstrap-services.txt >/dev/null
while IFS= read -r service; do
  grep -Fxq "$service" test-results/live/bootstrap-services.txt
done <<<"$expected_services"

gcloud storage buckets describe "gs://${bucket}" --format=json |
  tee test-results/live/bootstrap-state-bucket.json |
  jq -e '
    (.uniform_bucket_level_access // .iamConfiguration.uniformBucketLevelAccess.enabled) == true and
    (.public_access_prevention // .iamConfiguration.publicAccessPrevention) == "enforced" and
    (.versioning_enabled // .versioning.enabled) == true and
    ((.soft_delete_policy.retention_duration_seconds // .softDeletePolicy.retentionDurationSeconds // 0) | tonumber) >= 604800
  ' >/dev/null

gcloud iam workload-identity-pools providers describe github \
  --project "$project" --location global --workload-identity-pool github-actions --format=json \
  >test-results/live/bootstrap-wif-provider.json
jq -e '
  (.attributeCondition // .attribute_condition) as $condition |
  ["repository_id", "repository_owner_id", "refs/heads/main", "workflow_ref", "job_workflow_ref", "environment"] |
  all(. as $required | $condition | contains($required))
' test-results/live/bootstrap-wif-provider.json >/dev/null

for phase in foundation cluster delivery recovery; do
  service_account=$(jq -r --arg phase "$phase" '.[$phase]' <<<"$phase_accounts")
  test -n "$service_account"
  test -z "$(gcloud iam service-accounts keys list --iam-account "$service_account" --managed-by=user --format='value(name)')"
done

for service in iam.googleapis.com secretmanager.googleapis.com cloudkms.googleapis.com storage.googleapis.com; do
  gcloud projects get-iam-policy "$project" --format=json |
    jq -e --arg service "$service" '
      any(.auditConfigs[]?; .service == $service and
        ([.auditLogConfigs[].logType] | contains(["ADMIN_READ", "DATA_READ", "DATA_WRITE"])))
    ' >/dev/null
done
gcloud logging buckets describe _Default --location=global --project "$project" --format=json |
  tee test-results/live/bootstrap-log-retention.json | jq -e '.retentionDays == 30' >/dev/null

troubleshoot() {
  local phase=${1:?phase required}
  local permission=${2:?permission required}
  local expected=${3:?expected state required}
  local service_account result
  service_account=$(jq -r --arg phase "$phase" '.[$phase]' <<<"$phase_accounts")
  result="test-results/live/iam-troubleshooter/${phase}-${permission//./-}.json"
  gcloud policy-intelligence troubleshoot-policy iam "$project_resource" \
    --principal-email="$service_account" --permission="$permission" --format=json >"$result"
  jq -e --arg expected "$expected" '.overallAccessState == $expected' "$result" >/dev/null
}

troubleshoot foundation compute.networks.create CAN_ACCESS
troubleshoot foundation container.clusters.create CANNOT_ACCESS
troubleshoot cluster container.clusters.create CAN_ACCESS
troubleshoot cluster cloudkms.keyRings.create CANNOT_ACCESS
troubleshoot delivery cloudkms.keyRings.create CAN_ACCESS
troubleshoot delivery gkebackup.backupPlans.create CANNOT_ACCESS
troubleshoot recovery resourcemanager.projects.delete CAN_ACCESS
