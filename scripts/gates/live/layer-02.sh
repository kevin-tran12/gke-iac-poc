#!/usr/bin/env bash
set -euo pipefail
source scripts/gates/live/common.sh

network=$(tf_output network network_name)
subnet=$(tf_output network subnet_name)
subnet_cidr=$(tf_output network subnet_cidr)
pods_cidr=$(tf_output network pods_cidr)
services_cidr=$(tf_output network services_cidr)
private_services_range=$(tf_output network private_services_range_name)
private_services_cidr=$(tf_output network private_services_cidr)
nat_enabled=$(tf_output network nat_enabled)

gcloud compute networks describe "$network" \
  --project "$TF_VAR_project_id" --format=json |
  tee test-results/live/network.json |
  jq -e '
    .autoCreateSubnetworks == false and
    .routingConfig.routingMode == "REGIONAL"
  ' >/dev/null

gcloud compute networks subnets describe "$subnet" \
  --project "$TF_VAR_project_id" --region "$TF_VAR_region" --format=json |
  tee test-results/live/subnet.json |
  jq -e \
    --arg subnet_cidr "$subnet_cidr" \
    --arg pods_cidr "$pods_cidr" \
    --arg services_cidr "$services_cidr" '
      .ipCidrRange == $subnet_cidr and
      .privateIpGoogleAccess == true and
      (.secondaryIpRanges | length == 2) and
      any(.secondaryIpRanges[]; .rangeName == "pods" and .ipCidrRange == $pods_cidr) and
      any(.secondaryIpRanges[]; .rangeName == "services" and .ipCidrRange == $services_cidr) and
      .logConfig.enable == true and
      .logConfig.aggregationInterval == "INTERVAL_10_MIN" and
      .logConfig.flowSampling == 0.1 and
      .logConfig.metadata == "EXCLUDE_ALL_METADATA" and
      .logConfig.filterExpr == "true"
    ' >/dev/null

gcloud compute addresses describe "$private_services_range" \
  --project "$TF_VAR_project_id" --global --format=json |
  tee test-results/live/private-services-range.json |
  jq -e --arg cidr "$private_services_cidr" '
    .purpose == "VPC_PEERING" and
    .addressType == "INTERNAL" and
    ((.address + "/" + (.prefixLength | tostring)) == $cidr)
  ' >/dev/null

gcloud compute routes list \
  --project "$TF_VAR_project_id" --filter="network:$network" --format=json |
  tee test-results/live/network-routes.json |
  jq -e '
    any(.[]; .destRange == "0.0.0.0/0" and (.nextHopGateway // "" | endswith("/default-internet-gateway"))) and
    all(.[];
      (.nextHopInstance // "") == "" and
      (.nextHopIp // "") == "" and
      (.destRange != "0.0.0.0/0" or (.nextHopGateway // "" | endswith("/default-internet-gateway")))
    )
  ' >/dev/null

gcloud compute firewall-rules list \
  --project "$TF_VAR_project_id" --filter="network:$network" --format=json |
  tee test-results/live/network-firewall-rules.json |
  jq -e '
    [
      .[] |
      select(
        .direction == "INGRESS" and
        (.disabled // false) == false and
        any(.sourceRanges[]?; . == "0.0.0.0/0") and
        ((.allowed // []) | length > 0)
      )
    ] | length == 0
  ' >/dev/null

gcloud compute instances list --project "$TF_VAR_project_id" --format=json |
  tee test-results/live/compute-instances.json |
  jq -e --arg network "/networks/$network" '
    all(
      .[];
      all(
        .networkInterfaces[]?;
        ((.network // "") | endswith($network) | not) or ((.accessConfigs // []) | length == 0)
      )
    )
  ' >/dev/null

if gcloud compute networks describe default \
  --project "$TF_VAR_project_id" --format=json >test-results/live/default-network.json 2>/dev/null; then
  printf 'Unexpected default VPC exists in project %s\n' "$TF_VAR_project_id" >&2
  exit 1
else
  jq -n --arg project "$TF_VAR_project_id" '{project:$project,default_network_absent:true}' \
    >test-results/live/default-network.json
fi

if [[ $nat_enabled == true ]]; then
  router=$(tf_output network nat_router_name)
  nat=$(tf_output network nat_name)
  gcloud compute routers nats describe "$nat" \
    --project "$TF_VAR_project_id" --router "$router" --region "$TF_VAR_region" --format=json |
    tee test-results/live/cloud-nat.json |
    jq -e --arg subnet "$subnet" '
      .natIpAllocateOption == "AUTO_ONLY" and
      .sourceSubnetworkIpRangesToNat == "LIST_OF_SUBNETWORKS" and
      .logConfig.enable == true and
      .logConfig.filter == "ERRORS_ONLY" and
      any(.subnetworks[]; (.name // "" | endswith("/subnetworks/" + $subnet)))
    ' >/dev/null
  gcloud compute routers get-nat-ip-info "$router" \
    --project "$TF_VAR_project_id" --region "$TF_VAR_region" --format=json \
    >test-results/live/cloud-nat-ip-info.json
else
  gcloud compute routers list \
    --project "$TF_VAR_project_id" --regions "$TF_VAR_region" --format=json |
    tee test-results/live/cloud-nat.json |
    jq -e --arg router "${network}-router" '[.[] | select(.name == $router)] | length == 0' >/dev/null
  jq -n '{nat_enabled:false,allocated_ips:[]}' >test-results/live/cloud-nat-ip-info.json
fi
