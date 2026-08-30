#!/usr/bin/env bash
set -euo pipefail
source scripts/gates/live/common.sh

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
message_id=$(gcloud pubsub topics publish "$topic" --project "$TF_VAR_project_id" \
  --message=layer-3-gate --format='value(messageIds[0])')
test -n "$message_id"
for _ in {1..12}; do
  pulled=$(gcloud pubsub subscriptions pull "$subscription" --project "$TF_VAR_project_id" \
    --auto-ack --limit=1 --format=json)
  [[ $(jq 'length' <<<"$pulled") -gt 0 ]] && break
  sleep 5
done
[[ $(jq 'length' <<<"${pulled:-[]}") -gt 0 ]]
gcloud artifacts repositories describe "$(tf_output platform artifact_repository)" \
  --project "$TF_VAR_project_id" --location "$TF_VAR_region" --format=json \
  >test-results/live/artifact-registry.json
