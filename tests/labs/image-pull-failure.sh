#!/usr/bin/env bash
set -euo pipefail
namespace=${NAMESPACE:-staging}
deployment=${DEPLOYMENT:-gke-lab-api}
cleanup() { kubectl -n "$namespace" rollout undo deployment "$deployment" >/dev/null 2>&1 || true; }
trap cleanup EXIT

kubectl -n "$namespace" set image "deployment/$deployment" api=example.invalid/missing:failure-lab
if kubectl -n "$namespace" rollout status "deployment/$deployment" --timeout=90s; then
  printf 'expected the invalid image rollout to fail\n' >&2
  exit 1
fi
kubectl -n "$namespace" get pods -l app.kubernetes.io/name=gke-lab-api -o json |
  jq -e '.items[].status.containerStatuses[]? | select(.state.waiting.reason == "ImagePullBackOff" or .state.waiting.reason == "ErrImagePull")' >/dev/null
cleanup
trap - EXIT
kubectl -n "$namespace" rollout status "deployment/$deployment" --timeout=5m
