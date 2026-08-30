#!/usr/bin/env bash
set -euo pipefail

project_id=${1:?usage: scripts/adopt-project.sh PROJECT_ID BILLING_ACCOUNT [ORGANIZATION_ID]}
expected_billing=${2:?billing account ID required}
expected_organization=${3:-}
: "${BOOTSTRAP_TFVARS:?BOOTSTRAP_TFVARS must point to the populated bootstrap tfvars file}"

mkdir -p test-results/live
gcloud projects describe "$project_id" --format=json >test-results/live/adopt-project.json
gcloud billing projects describe "$project_id" --format=json >test-results/live/adopt-billing.json

test "$(jq -r '.lifecycleState' test-results/live/adopt-project.json)" = ACTIVE
actual_billing=$(jq -r '.billingAccountName | sub("^billingAccounts/"; "")' test-results/live/adopt-billing.json)
test "$actual_billing" = "$expected_billing" || {
  printf 'project billing account is %s, expected %s\n' "$actual_billing" "$expected_billing" >&2
  exit 1
}

parent=$(jq -r 'if (.parent | type) == "object" then .parent.id // "" else .parent // "" end' test-results/live/adopt-project.json)
parent=${parent#organizations/}
if [[ -n $expected_organization && $parent != "$expected_organization" ]]; then
  printf 'project organization is %s, expected %s\n' "${parent:-none}" "$expected_organization" >&2
  exit 1
fi
if [[ -z $expected_organization && -n $parent ]]; then
  printf 'project belongs to organization %s; pass that ID explicitly before import\n' "$parent" >&2
  exit 1
fi

if terraform -chdir=terraform/bootstrap state show google_project.lab >/dev/null 2>&1; then
  printf 'google_project.lab is already managed; adoption checks passed and no import was run.\n'
  exit 0
fi

terraform -chdir=terraform/bootstrap import -input=false \
  -var-file="$BOOTSTRAP_TFVARS" -var="bootstrap_profile=${BOOTSTRAP_PROFILE:-full}" \
  google_project.lab "$project_id"
printf 'Imported verified project %s into bootstrap state.\n' "$project_id"
