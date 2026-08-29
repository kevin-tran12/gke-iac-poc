#!/usr/bin/env bash
set -euo pipefail
node=${NODE_NAME:-$(kubectl get pods -n production -l app.kubernetes.io/name=gke-lab-api -o jsonpath='{.items[0].spec.nodeName}')}
test -n "$node"
cleanup() { kubectl uncordon "$node" >/dev/null 2>&1 || true; }
trap cleanup EXIT

kubectl cordon "$node"
if kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=60s; then
  printf 'drain succeeded; capture whether topology and spare replicas satisfied the PDB\n'
else
  kubectl get pdb -A
  kubectl get events -A --sort-by=.lastTimestamp | tail -30
fi
cleanup
