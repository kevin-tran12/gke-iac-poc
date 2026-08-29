#!/usr/bin/env bash
set -euo pipefail
namespace=${NAMESPACE:-staging}
name=allow-google-apis-and-telemetry
backup=$(mktemp)
kubectl -n "$namespace" get networkpolicy "$name" -o yaml >"$backup"
cleanup() { kubectl apply -f "$backup" >/dev/null 2>&1 || true; rm -f "$backup"; }
trap cleanup EXIT

kubectl -n "$namespace" patch networkpolicy "$name" --type=json -p='[{"op":"replace","path":"/spec/egress","value":[]}]'
sleep 15
kubectl -n "$namespace" logs deployment/gke-lab-worker --since=2m | grep -E 'Unavailable|DeadlineExceeded|permission|connection' >/dev/null
cleanup
trap - EXIT
kubectl -n "$namespace" rollout status deployment/gke-lab-worker --timeout=3m
