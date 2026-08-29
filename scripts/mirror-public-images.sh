#!/usr/bin/env bash
set -euo pipefail

: "${TF_VAR_project_id:?project ID required}"
: "${REGION:=us-central1}"
: "${ECHO_SOURCE:?approved echo source tag or digest required}"
: "${HELLO_SOURCE:?approved hello source tag or digest required}"
: "${HPA_SOURCE:?approved HPA source tag or digest required}"
: "${OTEL_SOURCE:?approved OpenTelemetry Collector source digest required}"
: "${RECOVERY_SOURCE:?approved recovery utility source digest required}"
: "${CERT_MANAGER_CONTROLLER_SOURCE:?approved cert-manager controller source digest required}"
: "${CERT_MANAGER_WEBHOOK_SOURCE:?approved cert-manager webhook source digest required}"
: "${CERT_MANAGER_CAINJECTOR_SOURCE:?approved cert-manager cainjector source digest required}"
: "${CERT_MANAGER_ACMESOLVER_SOURCE:?approved cert-manager ACME solver source digest required}"
: "${CERT_MANAGER_STARTUPAPICHECK_SOURCE:?approved cert-manager startup API check source digest required}"

registry="${REGION}-docker.pkg.dev/${TF_VAR_project_id}/gke-lab-containers"
mkdir -p test-results/live
output=test-results/live/mirrored-images.env
: >"$output"

mirror() {
  local variable=$1 source=$2 destination=$3
  docker pull "$source"
  docker tag "$source" "${registry}/${destination}:candidate"
  digest=$(docker push "${registry}/${destination}:candidate" | awk '/digest: sha256:/ {print $2}' | tail -1)
  [[ $digest =~ ^sha256:[0-9a-f]{64}$ ]] || { printf 'could not resolve digest for %s\n' "$destination" >&2; exit 1; }
  MIRRORED_IMAGE="${registry}/${destination}@${digest}"
  printf '%s=%s\n' "$variable" "$MIRRORED_IMAGE" | tee -a "$output"
}

mirror TF_VAR_echo_image "$ECHO_SOURCE" test-echo
mirror TF_VAR_hello_image "$HELLO_SOURCE" test-hello
mirror TF_VAR_hpa_image "$HPA_SOURCE" test-hpa
mirror TF_VAR_otel_collector_image "$OTEL_SOURCE" otel-collector
mirror TF_VAR_recovery_image "$RECOVERY_SOURCE" recovery-utility
mirror CERT_MANAGER_CONTROLLER_IMAGE "$CERT_MANAGER_CONTROLLER_SOURCE" cert-manager-controller
controller=$MIRRORED_IMAGE
mirror CERT_MANAGER_WEBHOOK_IMAGE "$CERT_MANAGER_WEBHOOK_SOURCE" cert-manager-webhook
webhook=$MIRRORED_IMAGE
mirror CERT_MANAGER_CAINJECTOR_IMAGE "$CERT_MANAGER_CAINJECTOR_SOURCE" cert-manager-cainjector
cainjector=$MIRRORED_IMAGE
mirror CERT_MANAGER_ACMESOLVER_IMAGE "$CERT_MANAGER_ACMESOLVER_SOURCE" cert-manager-acmesolver
acmesolver=$MIRRORED_IMAGE
mirror CERT_MANAGER_STARTUPAPICHECK_IMAGE "$CERT_MANAGER_STARTUPAPICHECK_SOURCE" cert-manager-startupapicheck
startupapicheck=$MIRRORED_IMAGE
cert_manager_json=$(jq -cn \
  --arg controller "$controller" --arg webhook "$webhook" \
  --arg cainjector "$cainjector" --arg acmesolver "$acmesolver" \
  --arg startupapicheck "$startupapicheck" \
  '{controller:$controller,webhook:$webhook,cainjector:$cainjector,acmesolver:$acmesolver,startupapicheck:$startupapicheck}')
printf 'TF_VAR_cert_manager_images=%s\n' "$cert_manager_json" | tee -a "$output"

printf 'Review and source %s into the protected GitHub repository variables.\n' "$output"
