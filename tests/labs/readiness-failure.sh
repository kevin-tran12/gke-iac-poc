#!/usr/bin/env bash
set -euo pipefail
namespace=${NAMESPACE:-staging}
deployment=gke-lab-api
cleanup() { kubectl -n "$namespace" rollout undo deployment "$deployment" >/dev/null 2>&1 || true; }
trap cleanup EXIT

kubectl -n "$namespace" patch deployment "$deployment" --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/intentional-failure"}]'
kubectl -n "$namespace" rollout status deployment "$deployment" --timeout=90s && { printf 'expected readiness rollout failure\n' >&2; exit 1; }
kubectl -n "$namespace" get endpointslices -l kubernetes.io/service-name=gke-lab-api -o json |
  jq -e '[.items[].endpoints[]? | select(.conditions.ready == true)] | length >= 1' >/dev/null
cleanup
trap - EXIT
kubectl -n "$namespace" rollout status deployment "$deployment" --timeout=5m
