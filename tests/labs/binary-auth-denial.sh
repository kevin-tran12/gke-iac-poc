#!/usr/bin/env bash
set -euo pipefail
namespace=staging
name=unsigned-image-test
cleanup() { kubectl -n "$namespace" delete deployment "$name" --ignore-not-found >/dev/null 2>&1 || true; }
trap cleanup EXIT

if kubectl -n "$namespace" create deployment "$name" --image=registry.k8s.io/pause:3.10; then
  sleep 10
fi
kubectl -n "$namespace" get events --field-selector reason=FailedCreate -o json |
  jq -e '.items[] | select(.message | test("attest|Binary Authorization|denied"; "i"))' >/dev/null
