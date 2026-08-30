#!/usr/bin/env bash
set -euo pipefail
source scripts/gates/live/common.sh

CLOUD_BUILD_SERVICE_ACCOUNT=$(tf_output platform cloud_build_service_account)
EVIDENCE_BUCKET=$(tf_output platform results_bucket)
BINAUTHZ_ATTESTOR=$(tf_output delivery attestor_name)
ATTESTATION_KEY_VERSION=$(tf_output delivery attestation_key_version)
export CLOUD_BUILD_SERVICE_ACCOUNT EVIDENCE_BUCKET BINAUTHZ_ATTESTOR ATTESTATION_KEY_VERSION
bash scripts/build-release.sh
token=$(gcloud secrets versions access latest --project "$TF_VAR_project_id" --secret gke-lab-api-token)
kubectl -n staging port-forward service/gke-lab-api 18080:80 >test-results/live/port-forward.log 2>&1 &
forward_pid=$!
cleanup() { kill "$forward_pid" >/dev/null 2>&1 || true; }
trap cleanup EXIT
for _ in {1..30}; do
  curl --fail --silent http://127.0.0.1:18080/healthz >/dev/null 2>&1 && break
  sleep 2
done
response=$(curl --fail --silent --show-error \
  --header "Authorization: Bearer ${token}" \
  --header 'Content-Type: application/json' \
  --data '{"payload":"layer-7-end-to-end"}' \
  http://127.0.0.1:18080/v1/jobs)
job_id=$(jq -er .job_id <<<"$response")
for _ in {1..60}; do
  status=$(curl --fail --silent --show-error --header "Authorization: Bearer ${token}" \
    "http://127.0.0.1:18080/v1/jobs/${job_id}")
  [[ $(jq -r .status <<<"$status") == completed ]] && break
  sleep 5
done
[[ $(jq -r .status <<<"${status:-{}}") == completed ]]
jq 'del(.result.digest)' <<<"$status" >test-results/live/job-journey.json
RESULTS_BUCKET=$(tf_output platform results_bucket)
export RESULTS_BUCKET
bash tests/labs/pubsub-redelivery.sh
bash scripts/run-binary-authorization-lab.sh
