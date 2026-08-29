#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer required}
profile=${2:-core}
export PROFILE=$profile

roots=(tooling bootstrap network platform cluster addons workloads delivery edge recovery)
(( layer >= 0 && layer < ${#roots[@]} )) || { printf 'layer must be 0-%s\n' "$((${#roots[@]} - 1))" >&2; exit 2; }
root=${roots[$layer]}

bash scripts/gates/check-prerequisites.sh "$layer"
mkdir -p test-results/live

init_state_root() {
  local dependency=$1
  terraform -chdir="terraform/${dependency}" init -input=false \
    -backend-config="bucket=${TF_STATE_BUCKET}" \
    -backend-config="prefix=state/${dependency}" >/dev/null
}

state_output() {
  local dependency=$1
  local output=$2
  terraform -chdir="terraform/${dependency}" output -raw "$output"
}

derive_layer_inputs() {
  if (( layer >= 3 )); then
    init_state_root network
    export TF_VAR_network_id="${TF_VAR_network_id:-$(state_output network network_id)}"
  fi

  if (( layer >= 4 )); then
    export TF_VAR_subnet_id="${TF_VAR_subnet_id:-$(state_output network subnet_id)}"
    export TF_VAR_pods_range_name="${TF_VAR_pods_range_name:-$(state_output network pods_range_name)}"
    export TF_VAR_services_range_name="${TF_VAR_services_range_name:-$(state_output network services_range_name)}"
    init_state_root platform
    export TF_VAR_api_service_account="${TF_VAR_api_service_account:-$(state_output platform api_service_account)}"
    export TF_VAR_worker_service_account="${TF_VAR_worker_service_account:-$(state_output platform worker_service_account)}"
    export TF_VAR_telemetry_service_account="${TF_VAR_telemetry_service_account:-$(state_output platform telemetry_service_account)}"
    export TF_VAR_cloud_deploy_service_account="${TF_VAR_cloud_deploy_service_account:-$(state_output platform cloud_deploy_service_account)}"
    export TF_VAR_artifact_bucket="${TF_VAR_artifact_bucket:-$(state_output platform results_bucket)}"
  fi

  if (( layer >= 5 )); then
    init_state_root cluster
    export TF_VAR_cluster_id="${TF_VAR_cluster_id:-$(state_output cluster cluster_id)}"
    export TF_VAR_cluster_dns_endpoint="${TF_VAR_cluster_dns_endpoint:-$(state_output cluster cluster_dns_endpoint)}"
    export TF_VAR_cluster_ca_certificate="${TF_VAR_cluster_ca_certificate:-$(state_output cluster cluster_ca_certificate)}"
  fi

  if (( layer == 7 )); then
    export TF_VAR_cloud_build_service_account="${TF_VAR_cloud_build_service_account:-$(state_output platform cloud_build_service_account)}"
  fi
}

profile_arguments() {
  case "${root}:${profile}" in
    network:egress)
      printf '%s\n' "-var-file=../profiles/egress.tfvars"
      ;;
    platform:data)
      printf '%s\n' "-var-file=../profiles/data.tfvars"
      ;;
    cluster:core|cluster:ha|cluster:recovery)
      printf '%s\n' "-var-file=../profiles/${profile}.tfvars"
      ;;
  esac
}

if (( layer == 0 )); then
  bash scripts/validate.sh
  bash scripts/gates/record-result.sh 0 passed
  exit 0
fi

if (( layer == 1 )); then
  test -n "${BOOTSTRAP_TFVARS:-}" || { printf 'BOOTSTRAP_TFVARS is required for the bootstrap live gate\n' >&2; exit 2; }
  terraform -chdir=terraform/bootstrap init -backend=false -input=false
  terraform -chdir=terraform/bootstrap plan -input=false -lock-timeout=60s -var-file="$BOOTSTRAP_TFVARS" -out=../../test-results/live/bootstrap.tfplan
  if [[ "${APPLY:-false}" == true ]]; then
    terraform -chdir=terraform/bootstrap apply -input=false ../../test-results/live/bootstrap.tfplan
  fi
else
  : "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
  : "${TF_VAR_project_id:?TF_VAR_project_id is required}"
  derive_layer_inputs
  mapfile -t profile_args < <(profile_arguments)
  terraform -chdir="terraform/${root}" init -input=false \
    -backend-config="bucket=${TF_STATE_BUCKET}" -backend-config="prefix=state/${root}"
  terraform -chdir="terraform/${root}" plan -input=false -lock-timeout=60s \
    "${profile_args[@]}" -out="../../test-results/live/${root}.tfplan"
  if [[ "${APPLY:-false}" == true ]]; then
    terraform -chdir="terraform/${root}" apply -input=false "../../test-results/live/${root}.tfplan"
  fi
fi

PLAN_DIGEST=$(sha256sum "test-results/live/${root}.tfplan" | cut -d' ' -f1)
export PLAN_DIGEST
if [[ "${APPLY:-false}" == true ]]; then
  TF_STATE_SERIAL=$(terraform -chdir="terraform/${root}" state pull | jq -r .serial)
  export TF_STATE_SERIAL
  bash scripts/gates/test-live-layer.sh "$layer" "$profile"
fi
bash scripts/gates/record-result.sh "$layer" passed
