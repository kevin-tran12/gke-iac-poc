#!/usr/bin/env bash
set -euo pipefail
source scripts/gates/live/common.sh

test "$(tf_output network nat_enabled)" = true || {
  printf 'public TLS requires the approval-gated egress profile\n' >&2
  exit 1
}
LAB_BASE_URL=$(tf_output edge https_url)
export LAB_BASE_URL
kubectl -n test wait --for=condition=Programmed gateway/public --timeout=20m
kubectl -n test wait --for=condition=Ready certificate/public-tls --timeout=20m
curl --fail --show-error --location "$LAB_BASE_URL/echo" >test-results/live/public-echo.json
bash tests/labs/cloud-armor.sh
