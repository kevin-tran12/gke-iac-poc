#!/usr/bin/env bash
set -euo pipefail

: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
: "${TF_VAR_project_id:?TF_VAR_project_id is required}"
export TF_VAR_region=${TF_VAR_region:-us-central1}
mkdir -p test-results

init_root() {
  terraform -chdir="terraform/$1" init -input=false \
    -backend-config="bucket=${TF_STATE_BUCKET}" -backend-config="prefix=state/$1" >/dev/null
}
output() {
  terraform -chdir="terraform/$1" output -raw "$2"
}
destroy() {
  [[ ${active_roots[$1]:-false} == true ]] || { printf 'Skipping %s; no remote state exists.\n' "$1"; return; }
  printf 'Destroying %s...\n' "$1"
  terraform -chdir="terraform/$1" destroy -auto-approve -input=false -lock-timeout=120s
}

declare -A active_roots
for root in network platform cluster addons workloads delivery edge recovery; do
  if gcloud storage ls "gs://${TF_STATE_BUCKET}/state/${root}/default.tfstate" >/dev/null 2>&1; then
    active_roots[$root]=true
    init_root "$root"
  fi
done

if [[ ${active_roots[network]:-false} == true ]]; then
  TF_VAR_network_id=$(output network network_id)
  TF_VAR_subnet_id=$(output network subnet_id)
  TF_VAR_pods_range_name=$(output network pods_range_name)
  TF_VAR_services_range_name=$(output network services_range_name)
  export TF_VAR_network_id TF_VAR_subnet_id TF_VAR_pods_range_name TF_VAR_services_range_name
fi
if [[ ${active_roots[platform]:-false} == true ]]; then
  TF_VAR_api_service_account=$(output platform api_service_account)
  TF_VAR_worker_service_account=$(output platform worker_service_account)
  TF_VAR_telemetry_service_account=$(output platform telemetry_service_account)
  TF_VAR_cloud_build_service_account=$(output platform cloud_build_service_account)
  TF_VAR_cloud_deploy_service_account=$(output platform cloud_deploy_service_account)
  TF_VAR_artifact_bucket=$(output platform results_bucket)
  export TF_VAR_api_service_account TF_VAR_worker_service_account TF_VAR_telemetry_service_account
  export TF_VAR_cloud_build_service_account TF_VAR_cloud_deploy_service_account TF_VAR_artifact_bucket
fi
if [[ ${active_roots[cluster]:-false} == true ]]; then
  TF_VAR_cluster_id=$(output cluster cluster_id)
  TF_VAR_cluster_dns_endpoint=$(output cluster cluster_dns_endpoint)
  TF_VAR_cluster_ca_certificate=$(output cluster cluster_ca_certificate)
  export TF_VAR_cluster_id TF_VAR_cluster_dns_endpoint TF_VAR_cluster_ca_certificate
fi
export TF_VAR_acme_email=${TF_VAR_acme_email:-destroy@example.invalid}

dummy_digest="example.invalid/lab@sha256:$(printf '0%.0s' {1..64})"
export TF_VAR_echo_image=${TF_VAR_echo_image:-$dummy_digest}
export TF_VAR_hello_image=${TF_VAR_hello_image:-$dummy_digest}
export TF_VAR_hpa_image=${TF_VAR_hpa_image:-$dummy_digest}
export TF_VAR_recovery_image=${TF_VAR_recovery_image:-$dummy_digest}
export TF_VAR_otel_collector_image=${TF_VAR_otel_collector_image:-$dummy_digest}
export TF_VAR_cert_manager_images=${TF_VAR_cert_manager_images:-"{\"controller\":\"$dummy_digest\",\"webhook\":\"$dummy_digest\",\"cainjector\":\"$dummy_digest\",\"acmesolver\":\"$dummy_digest\",\"startupapicheck\":\"$dummy_digest\"}"}
destroy recovery
destroy edge
destroy delivery
destroy workloads
destroy addons
destroy cluster
destroy platform
destroy network

bash scripts/verify-no-billable-resources.sh | tee test-results/teardown-runtime.txt
