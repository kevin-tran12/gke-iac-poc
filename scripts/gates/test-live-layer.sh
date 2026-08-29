#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer required}
profile=${2:-core}
TF_VAR_project_id=${TF_VAR_project_id:?TF_VAR_project_id is required}
TF_VAR_region=${TF_VAR_region:?TF_VAR_region is required}
mkdir -p test-results/live

tf_output() {
  terraform -chdir="terraform/$1" output -raw "$2"
}

case "$layer" in
  1)
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
    ;;
  2)
    gcloud compute networks describe "$(tf_output network network_name)" --project "$TF_VAR_project_id" --format=json >test-results/live/network.json
    gcloud compute networks subnets describe "$(tf_output network subnet_name)" --project "$TF_VAR_project_id" --region "$TF_VAR_region" --format=json |
      tee test-results/live/subnet.json | jq -e '.privateIpGoogleAccess == true and (.secondaryIpRanges | length == 2)' >/dev/null
    ;;
  3)
    bucket=$(tf_output platform results_bucket)
    topic=$(tf_output platform jobs_topic)
    subscription=$(tf_output platform jobs_subscription)
    probe=$(mktemp)
    object="gs://${bucket}/gate-probes/layer-3-$(git rev-parse --short HEAD).txt"
    cleanup() { rm -f "$probe"; gcloud storage rm "$object" >/dev/null 2>&1 || true; }
    trap cleanup EXIT
    printf 'layer-3\n' >"$probe"
    gcloud storage cp --if-generation-match=0 "$probe" "$object" >/dev/null
    if gcloud storage cp --if-generation-match=0 "$probe" "$object" >/dev/null 2>&1; then
      printf 'GCS generation precondition allowed a duplicate create\n' >&2
      exit 1
    fi
    message_id=$(gcloud pubsub topics publish "$topic" --project "$TF_VAR_project_id" --message=layer-3-gate --format='value(messageIds[0])')
    test -n "$message_id"
    for _ in {1..12}; do
      pulled=$(gcloud pubsub subscriptions pull "$subscription" --project "$TF_VAR_project_id" --auto-ack --limit=1 --format=json)
      [[ $(jq 'length' <<<"$pulled") -gt 0 ]] && break
      sleep 5
    done
    [[ $(jq 'length' <<<"${pulled:-[]}") -gt 0 ]]
    gcloud artifacts repositories describe "$(tf_output platform artifact_repository)" --project "$TF_VAR_project_id" --location "$TF_VAR_region" --format=json >test-results/live/artifact-registry.json
    ;;
  4)
    cluster=$(tf_output cluster cluster_name)
    location=$(tf_output cluster cluster_location)
    gcloud container clusters get-credentials "$cluster" --project "$TF_VAR_project_id" --location "$location" --dns-endpoint
    gcloud container clusters describe "$cluster" --project "$TF_VAR_project_id" --location "$location" --format=json |
      tee test-results/live/cluster.json | jq -e '
        .privateClusterConfig.enablePrivateNodes == true and
        .datapathProvider == "ADVANCED_DATAPATH" and
        .networkingMode == "VPC_NATIVE" and
        .controlPlaneEndpointsConfig.ipEndpointsConfig.enabled == false and
        (.controlPlaneEndpointsConfig.dnsEndpointConfig.endpoint | length) > 0 and
        .releaseChannel.channel == "REGULAR" and
        .dnsConfig.clusterDns == "CLOUD_DNS" and
        (.workloadIdentityConfig.workloadPool | endswith(".svc.id.goog")) and
        .gatewayApiConfig.channel == "CHANNEL_STANDARD" and
        .monitoringConfig.managedPrometheusConfig.enabled == true
      ' >/dev/null
    gcloud container node-pools describe system --cluster "$cluster" --project "$TF_VAR_project_id" --location "$location" --format=json |
      tee test-results/live/system-node-pool.json | jq -e '
        .config.shieldedInstanceConfig.enableSecureBoot == true and
        .config.workloadMetadataConfig.mode == "GKE_METADATA" and
        .management.autoRepair == true and
        .management.autoUpgrade == true and
        .config.serviceAccount != "default"
      ' >/dev/null
    gcloud container node-pools describe spot-apps --cluster "$cluster" --project "$TF_VAR_project_id" --location "$location" --format=json |
      tee test-results/live/spot-node-pool.json | jq -e '
        .config.spot == true and
        .autoscaling.totalMinNodeCount == 0 and
        .autoscaling.totalMaxNodeCount == 3
      ' >/dev/null
    kubectl wait --for=condition=Ready node --all --timeout=10m
    kubectl get nodes -o json | tee test-results/live/nodes.json |
      jq -e '(.items | length) >= 1 and ([.items[].status.addresses[]? | select(.type == "ExternalIP")] | length) == 0' >/dev/null
    ;;
  5)
    kubectl -n cert-manager rollout status deployment/cert-manager --timeout=10m
    kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=10m
    kubectl -n observability rollout status deployment/otel-collector --timeout=10m
    kubectl get validatingwebhookconfigurations -o json >test-results/live/webhooks.json
    ;;
  6)
    kubectl -n test rollout status deployment/echo --timeout=10m
    kubectl -n test rollout status deployment/hello --timeout=10m
    kubectl -n test rollout status deployment/hpa-example --timeout=10m
    kubectl -n recovery rollout status statefulset/recovery-proof --timeout=10m
    kubectl -n recovery exec statefulset/recovery-proof -- wget -qO- http://echo.test.svc.cluster.local/headers >test-results/live/echo.json
    for _ in {1..12}; do kubectl -n recovery exec statefulset/recovery-proof -- wget -qO- http://hello.test.svc.cluster.local; done >test-results/live/hello-load-balancing.txt
    test "$(grep -o 'Hostname: [^ ]*' test-results/live/hello-load-balancing.txt | sort -u | wc -l)" -ge 2
    proof_before=$(kubectl -n recovery exec statefulset/recovery-proof -- cat /data/proof.txt)
    kubectl -n recovery delete pod recovery-proof-0 --wait=true
    kubectl -n recovery rollout status statefulset/recovery-proof --timeout=10m
    proof_after=$(kubectl -n recovery exec statefulset/recovery-proof -- cat /data/proof.txt)
    test "$proof_before" = "$proof_after"
    printf '%s\n' "$proof_after" >test-results/live/persistent-volume-proof.txt
    bash tests/labs/hpa-and-node-scaling.sh
    ;;
  7)
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
    for _ in {1..30}; do curl --fail --silent http://127.0.0.1:18080/healthz >/dev/null 2>&1 && break; sleep 2; done
    response=$(curl --fail --silent --show-error \
      --header "Authorization: Bearer ${token}" \
      --header 'Content-Type: application/json' \
      --data '{"payload":"layer-7-end-to-end"}' \
      http://127.0.0.1:18080/v1/jobs)
    job_id=$(jq -er .job_id <<<"$response")
    for _ in {1..60}; do
      status=$(curl --fail --silent --show-error --header "Authorization: Bearer ${token}" "http://127.0.0.1:18080/v1/jobs/${job_id}")
      [[ $(jq -r .status <<<"$status") == completed ]] && break
      sleep 5
    done
    [[ $(jq -r .status <<<"${status:-{}}") == completed ]]
    jq 'del(.result.digest)' <<<"$status" >test-results/live/job-journey.json
    RESULTS_BUCKET=$(tf_output platform results_bucket)
    export RESULTS_BUCKET
    bash tests/labs/pubsub-redelivery.sh
    bash scripts/run-binary-authorization-lab.sh
    ;;
  8)
    test "$(tf_output network nat_enabled)" = true || { printf 'public TLS requires the approval-gated egress profile\n' >&2; exit 1; }
    LAB_BASE_URL=$(tf_output edge https_url)
    export LAB_BASE_URL
    kubectl -n test wait --for=condition=Programmed gateway/public --timeout=20m
    kubectl -n test wait --for=condition=Ready certificate/public-tls --timeout=20m
    curl --fail --show-error --location "$LAB_BASE_URL/echo" >test-results/live/public-echo.json
    bash tests/labs/cloud-armor.sh
    ;;
  9)
    test "$profile" = recovery || { printf 'layer 9 requires PROFILE=recovery\n' >&2; exit 2; }
    test "$(tf_output cluster backup_agent_enabled)" = true || { printf 'cluster must be applied with the recovery profile first\n' >&2; exit 1; }
    BACKUP_PLAN=$(tf_output recovery backup_plan)
    RESTORE_PLAN=$(tf_output recovery restore_plan)
    export BACKUP_PLAN RESTORE_PLAN
    export REGION=$TF_VAR_region
    bash tests/labs/persistent-disk-restore.sh
    ;;
  *)
    printf 'No live test is defined for layer %s\n' "$layer" >&2
    exit 2
    ;;
esac
