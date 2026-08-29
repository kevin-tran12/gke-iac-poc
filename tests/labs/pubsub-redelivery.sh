#!/usr/bin/env bash
set -euo pipefail
: "${TF_VAR_project_id:?project required}"
job_id=$(python3 -c 'import uuid; print(uuid.uuid4())')
message=$(jq -nc --arg id "$job_id" '{version:1,job_id:$id,payload:"synthetic-redelivery",submitted_at:(now|todate),traceparent:""}')
for _ in 1 2; do gcloud pubsub topics publish gke-lab-jobs --project "$TF_VAR_project_id" --message "$message" >/dev/null; done
sleep 30
gcloud storage ls "gs://${RESULTS_BUCKET:?}/results/${job_id}.json" >/dev/null
count=$(gcloud storage objects list "gs://${RESULTS_BUCKET}/results/${job_id}.json" --format='value(name)' | wc -l)
test "$count" -eq 1
