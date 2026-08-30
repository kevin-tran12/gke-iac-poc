#!/usr/bin/env bash

# Shared by the explicit plan, apply, verify, and destroy entry points. Callers
# enable their own strict shell options so this file can also be sourced by tests.

roots=(tooling bootstrap network platform cluster addons workloads delivery edge recovery)

validate_layer() {
  local layer=${1:?layer required}
  (( layer >= 0 && layer < ${#roots[@]} )) || {
    printf 'layer must be 0-%s\n' "$((${#roots[@]} - 1))" >&2
    return 2
  }
}

root_for_layer() {
  local layer=${1:?layer required}
  validate_layer "$layer"
  printf '%s\n' "${roots[$layer]}"
}

require_clean_tree() {
  if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
    printf 'apply and verification require a clean working tree so evidence matches reviewed source\n' >&2
    return 1
  fi
}

init_state_root() {
  local dependency=${1:?Terraform root required}
  : "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
  terraform -chdir="terraform/${dependency}" init -input=false \
    -backend-config="bucket=${TF_STATE_BUCKET}" \
    -backend-config="prefix=state/${dependency}" >/dev/null
}

state_output() {
  local dependency=${1:?Terraform root required}
  local output=${2:?Terraform output required}
  terraform -chdir="terraform/${dependency}" output -raw "$output"
}

derive_layer_inputs() {
  local layer=${1:?layer required}

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
  local root=${1:?Terraform root required}
  local profile=${2:-core}

  case "${root}:${profile}" in
    network:egress|network:full)
      printf '%s\n' '-var-file=../profiles/egress.tfvars'
      ;;
    platform:data|platform:full)
      printf '%s\n' '-var-file=../profiles/data.tfvars'
      ;;
    cluster:core|cluster:ha|cluster:recovery)
      printf '%s\n' "-var-file=../profiles/${profile}.tfvars"
      ;;
    cluster:full)
      printf '%s\n' '-var-file=../profiles/ha.tfvars' '-var-file=../profiles/recovery.tfvars'
      ;;
  esac
}

prepare_layer() {
  local layer=${1:?layer required}
  local profile=${2:-core}
  local root
  root=$(root_for_layer "$layer")
  export PROFILE=$profile
  export LAYER_ROOT=$root
  export AFFECTED_ROOTS=${AFFECTED_ROOTS:-$root}

  if (( layer == 0 )); then
    return
  fi
  if (( layer == 1 )); then
    test -n "${BOOTSTRAP_TFVARS:-}" || {
      printf 'BOOTSTRAP_TFVARS is required for layer 1\n' >&2
      return 2
    }
    if [[ -f terraform/bootstrap/backend.tf ]]; then
      : "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required after bootstrap state migration}"
      init_state_root bootstrap
    else
      terraform -chdir=terraform/bootstrap init -backend=false -input=false
    fi
    return
  fi

  : "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
  : "${TF_VAR_project_id:?TF_VAR_project_id is required}"
  derive_layer_inputs "$layer"
  init_state_root "$root"
}

layer_input_digest() {
  local layer=${1:?layer required}
  local profile=${2:-core}
  local root
  root=$(root_for_layer "$layer")

  {
    printf 'layer=%s\nprofile=%s\nroot=%s\n' "$layer" "$profile" "$root"
    while IFS= read -r name; do
      printf '%s=%s\n' "$name" "${!name}"
    done < <(compgen -v | LC_ALL=C grep '^TF_VAR_' | LC_ALL=C sort)
    if [[ -n "${BOOTSTRAP_TFVARS:-}" ]]; then
      printf 'bootstrap_tfvars_sha256=%s\n' "$(sha256sum "$BOOTSTRAP_TFVARS" | cut -d' ' -f1)"
    fi
    while IFS= read -r argument; do
      printf 'profile_argument=%s\n' "$argument"
    done < <(profile_arguments "$root" "$profile")
  } | sha256sum | cut -d' ' -f1
}

plan_path_for_layer() {
  local layer=${1:?layer required}
  printf 'test-results/live/%s.tfplan\n' "$(root_for_layer "$layer")"
}

manifest_path_for_layer() {
  local layer=${1:?layer required}
  printf 'test-results/live/%s.plan.json\n' "$(root_for_layer "$layer")"
}

refresh_bootstrap_outputs() {
  TF_VAR_project_id="$(state_output bootstrap project_id)"
  TF_VAR_project_number="$(state_output bootstrap project_number)"
  TF_VAR_region="$(state_output bootstrap region)"
  TF_STATE_BUCKET="$(state_output bootstrap state_bucket)"
  export TF_VAR_project_id TF_VAR_project_number TF_VAR_region TF_STATE_BUCKET
}
