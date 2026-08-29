#!/usr/bin/env bash
set -euo pipefail

stamp=$(date -u +%Y%m%dT%H%M%SZ)
dir="evidence/raw/${stamp}"
mkdir -p "$dir"
git rev-parse HEAD >"$dir/commit.txt"
kubectl get nodes,pods,services,hpa -A -o wide >"$dir/kubernetes-summary.txt" 2>&1 || true
gcloud monitoring dashboards list --format=json >"$dir/dashboards.json" 2>&1 || true
gcloud billing projects describe "${TF_VAR_project_id:-missing}" --format=json >"$dir/billing-link.json" 2>&1 || true
cp .gate-state/*.json "$dir/" 2>/dev/null || true
printf 'Raw evidence written to %s; sanitize before committing anything.\n' "$dir"
