#!/usr/bin/env bash
set -euo pipefail
: "${FAILURE_ZONE:?zone to simulate must be explicit}"
kubectl get nodes -L topology.kubernetes.io/zone
victims=$(kubectl get nodes -l "topology.kubernetes.io/zone=${FAILURE_ZONE}" -o name)
test -n "$victims"
for node in $victims; do kubectl cordon "$node"; done
cleanup() { for node in $victims; do kubectl uncordon "$node" >/dev/null 2>&1 || true; done; }
trap cleanup EXIT
for node in $victims; do kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=5m; done
kubectl -n production rollout status deployment/gke-lab-api --timeout=5m
cleanup
