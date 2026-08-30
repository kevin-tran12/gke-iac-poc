#!/usr/bin/env bash
set -euo pipefail
source scripts/gates/live/common.sh

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
