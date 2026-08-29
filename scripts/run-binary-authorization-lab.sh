#!/usr/bin/env bash
set -euo pipefail

: "${TF_STATE_BUCKET:?state bucket required}"
mkdir -p test-results/live

regional=$(terraform -chdir=terraform/cluster output -raw regional)
backup_agent=$(terraform -chdir=terraform/cluster output -raw backup_agent_enabled)

set_enforcement() {
  local enabled=$1 label=$2
  terraform -chdir=terraform/cluster plan -input=false -lock-timeout=60s \
    -var="regional=${regional}" \
    -var="enable_backup_agent=${backup_agent}" \
    -var="enable_binary_authorization=${enabled}" \
    -out="../../test-results/live/binary-authorization-${label}.tfplan"
  terraform -chdir=terraform/cluster apply -input=false "../../test-results/live/binary-authorization-${label}.tfplan"
}

cleanup() { set_enforcement false disabled >/dev/null 2>&1 || true; }
trap cleanup EXIT

set_enforcement true enabled
bash tests/labs/binary-auth-denial.sh
kubectl -n staging rollout restart deployment/gke-lab-api
kubectl -n staging rollout status deployment/gke-lab-api --timeout=10m
printf 'Unsigned image was denied and the attested application image rolled out successfully.\n' >test-results/live/binary-authorization.txt

set_enforcement false disabled
trap - EXIT
