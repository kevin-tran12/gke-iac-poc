#!/usr/bin/env bash
set -euo pipefail
: "${LOAD_IMAGE:?digest-pinned curl or load image required}"
namespace="test"
before_nodes=$(kubectl get nodes --no-headers | wc -l)
cleanup() { kubectl -n "$namespace" delete job hpa-load --ignore-not-found >/dev/null 2>&1 || true; }
trap cleanup EXIT

# These expressions must expand inside the Kubernetes Job, not in this shell.
# shellcheck disable=SC2016
kubectl -n "$namespace" create job hpa-load --image="$LOAD_IMAGE" -- /bin/sh -c 'end=$((SECONDS+180)); while [ $SECONDS -lt $end ]; do wget -q -O- http://hpa-example >/dev/null; done'
scale_deadline=$((SECONDS+300))
while (( SECONDS < scale_deadline )); do
  replicas=$(kubectl -n "$namespace" get hpa hpa-example -o jsonpath='{.status.currentReplicas}')
  (( ${replicas:-0} >= 2 )) && break
  sleep 5
done
(( ${replicas:-0} >= 2 )) || { printf 'HPA did not scale above one replica\n' >&2; exit 1; }
deadline=$((SECONDS+600))
while (( SECONDS < deadline )); do
  current=$(kubectl get nodes --no-headers | wc -l)
  (( current > before_nodes )) && break
  sleep 10
done
kubectl get hpa hpa-example -n "$namespace"
cleanup
scale_down_deadline=$((SECONDS+600))
while (( SECONDS < scale_down_deadline )); do
  replicas=$(kubectl -n "$namespace" get hpa hpa-example -o jsonpath='{.status.currentReplicas}')
  (( ${replicas:-1} <= 1 )) && break
  sleep 15
done
(( ${replicas:-1} <= 1 )) || { printf 'HPA did not return to its minimum replica count\n' >&2; exit 1; }
