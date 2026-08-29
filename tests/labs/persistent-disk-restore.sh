#!/usr/bin/env bash
set -euo pipefail
: "${TF_VAR_project_id:?project required}"
: "${REGION:=us-central1}"
: "${BACKUP_PLAN:?Backup for GKE plan ID required}"
: "${RESTORE_PLAN:?Backup for GKE restore plan ID required}"
backup="proof-$(date -u +%Y%m%d%H%M%S)"
restore="${backup}-restore"
backup_plan_name=${BACKUP_PLAN##*/}
restore_plan_name=${RESTORE_PLAN##*/}
backup_id="projects/${TF_VAR_project_id}/locations/${REGION}/backupPlans/${backup_plan_name}/backups/${backup}"
cleanup() {
  gcloud beta container backup-restore restores delete "$restore" --project "$TF_VAR_project_id" --location "$REGION" --restore-plan "$restore_plan_name" --quiet >/dev/null 2>&1 || true
  gcloud beta container backup-restore backups delete "$backup" --project "$TF_VAR_project_id" --location "$REGION" --backup-plan "$backup_plan_name" --quiet >/dev/null 2>&1 || true
}
trap cleanup EXIT

before=$(kubectl -n recovery exec statefulset/recovery-proof -- cat /data/proof.txt)
gcloud beta container backup-restore backups create "$backup" --project "$TF_VAR_project_id" --location "$REGION" --backup-plan "$BACKUP_PLAN" --wait-for-completion
kubectl -n recovery delete statefulset recovery-proof
kubectl -n recovery delete pvc data-recovery-proof-0
printf '%s\n' "$before" >test-results/recovery-proof-before.txt
gcloud beta container backup-restore restores create "$restore" --project "$TF_VAR_project_id" --location "$REGION" --restore-plan "$RESTORE_PLAN" --backup "$backup_id" --wait-for-completion
kubectl -n recovery rollout status statefulset/recovery-proof --timeout=10m
after=$(kubectl -n recovery exec statefulset/recovery-proof -- cat /data/proof.txt)
printf '%s\n' "$after" >test-results/recovery-proof-after.txt
test "$before" = "$after"
printf 'Persistent Disk proof restored exactly: %s\n' "$after"
