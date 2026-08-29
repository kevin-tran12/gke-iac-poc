#!/usr/bin/env bash
set -euo pipefail
: "${TF_VAR_project_id:?project required}"
: "${SQL_INSTANCE:=gke-lab-postgres}"
backup_id=$(gcloud sql backups create --project "$TF_VAR_project_id" --instance "$SQL_INSTANCE" --description failure-lab --format='value(id)')
test -n "$backup_id"
gcloud sql backups describe "$backup_id" --project "$TF_VAR_project_id" --instance "$SQL_INSTANCE" --format=json | jq -e '.status == "SUCCESSFUL"' >/dev/null
printf 'Backup %s is ready. Perform destructive/PITR steps only under the paid-profile runbook approval.\n' "$backup_id"
