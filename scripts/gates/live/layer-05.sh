#!/usr/bin/env bash
set -euo pipefail
source scripts/gates/live/common.sh

kubectl -n cert-manager rollout status deployment/cert-manager --timeout=10m
kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=10m
kubectl -n observability rollout status deployment/otel-collector --timeout=10m
kubectl get validatingwebhookconfigurations -o json >test-results/live/webhooks.json
