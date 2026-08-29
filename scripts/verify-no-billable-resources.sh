#!/usr/bin/env bash
set -euo pipefail

: "${TF_VAR_project_id:?TF_VAR_project_id is required}"
project=$TF_VAR_project_id
report=${ZERO_COST_REPORT:-test-results/zero-cost-inventory.json}
mkdir -p "$(dirname "$report")"

clusters=$(gcloud container clusters list --project "$project" --format=json)
instances=$(gcloud compute instances list --project "$project" --format=json)
forwarding=$(gcloud compute forwarding-rules list --project "$project" --format=json)
addresses=$(gcloud compute addresses list --project "$project" --format=json)
disks=$(gcloud compute disks list --project "$project" --format=json)
routers=$(gcloud compute routers list --project "$project" --format=json)
sql=$(gcloud sql instances list --project "$project" --format=json)
dns=$(gcloud dns managed-zones list --project "$project" --format=json)
topics=$(gcloud pubsub topics list --project "$project" --format=json)
secrets=$(gcloud secrets list --project "$project" --format=json)
repos=$(gcloud artifacts repositories list --project "$project" --location=all --format=json)

jq -n \
  --arg project "$project" \
  --arg checked_at "$(date -u +%FT%TZ)" \
  --argjson clusters "$clusters" --argjson instances "$instances" \
  --argjson forwarding_rules "$forwarding" --argjson addresses "$addresses" \
  --argjson disks "$disks" --argjson routers "$routers" --argjson cloud_sql "$sql" \
  --argjson dns_zones "$dns" --argjson pubsub_topics "$topics" \
  --argjson secrets "$secrets" --argjson artifact_repositories "$repos" \
  '{project:$project,checked_at:$checked_at,clusters:$clusters,instances:$instances,forwarding_rules:$forwarding_rules,addresses:$addresses,disks:$disks,routers:$routers,cloud_sql:$cloud_sql,dns_zones:$dns_zones,pubsub_topics:$pubsub_topics,secrets:$secrets,artifact_repositories:$artifact_repositories}' \
  >"$report"

remaining=$(jq '[.clusters,.instances,.forwarding_rules,.addresses,.disks,.routers,.cloud_sql,.dns_zones,.pubsub_topics,.secrets,.artifact_repositories] | map(length) | add' "$report")
if (( remaining != 0 )); then
  jq '{counts:{clusters:(.clusters|length),instances:(.instances|length),forwarding_rules:(.forwarding_rules|length),addresses:(.addresses|length),disks:(.disks|length),routers:(.routers|length),cloud_sql:(.cloud_sql|length),dns_zones:(.dns_zones|length),pubsub_topics:(.pubsub_topics|length),secrets:(.secrets|length),artifact_repositories:(.artifact_repositories|length)}}' "$report" >&2
  exit 1
fi
printf 'Independent inventory found no known billable runtime resources.\n'
