#!/usr/bin/env bash
set -euo pipefail
source scripts/gates/live/common.sh

kubectl -n test rollout status deployment/echo --timeout=10m
kubectl -n test rollout status deployment/hello --timeout=10m
kubectl -n test rollout status deployment/hpa-example --timeout=10m
kubectl -n recovery rollout status statefulset/recovery-proof --timeout=10m
kubectl -n recovery exec statefulset/recovery-proof -- \
  wget -qO- http://echo.test.svc.cluster.local/headers >test-results/live/echo.json
for _ in {1..12}; do
  kubectl -n recovery exec statefulset/recovery-proof -- wget -qO- http://hello.test.svc.cluster.local
done >test-results/live/hello-load-balancing.txt
test "$(grep -o 'Hostname: [^ ]*' test-results/live/hello-load-balancing.txt | sort -u | wc -l)" -ge 2
proof_before=$(kubectl -n recovery exec statefulset/recovery-proof -- cat /data/proof.txt)
kubectl -n recovery delete pod recovery-proof-0 --wait=true
kubectl -n recovery rollout status statefulset/recovery-proof --timeout=10m
proof_after=$(kubectl -n recovery exec statefulset/recovery-proof -- cat /data/proof.txt)
test "$proof_before" = "$proof_after"
printf '%s\n' "$proof_after" >test-results/live/persistent-volume-proof.txt
bash tests/labs/hpa-and-node-scaling.sh
