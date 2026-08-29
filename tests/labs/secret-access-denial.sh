#!/usr/bin/env bash
set -euo pipefail
: "${TF_VAR_project_id:?project required}"
: "${API_SERVICE_ACCOUNT:?API service account required}"
secret=gke-lab-api-token
member="serviceAccount:${API_SERVICE_ACCOUNT}"
cleanup() { gcloud secrets add-iam-policy-binding "$secret" --project "$TF_VAR_project_id" --member "$member" --role roles/secretmanager.secretAccessor >/dev/null 2>&1 || true; }
trap cleanup EXIT

gcloud secrets remove-iam-policy-binding "$secret" --project "$TF_VAR_project_id" --member "$member" --role roles/secretmanager.secretAccessor >/dev/null
kubectl -n staging rollout restart deployment/gke-lab-api
kubectl -n staging rollout status deployment/gke-lab-api --timeout=90s && { printf 'expected fail-closed startup\n' >&2; exit 1; }
kubectl -n staging logs deployment/gke-lab-api --since=2m | grep -F 'token access failed' >/dev/null
cleanup
trap - EXIT
kubectl -n staging rollout restart deployment/gke-lab-api
kubectl -n staging rollout status deployment/gke-lab-api --timeout=5m
