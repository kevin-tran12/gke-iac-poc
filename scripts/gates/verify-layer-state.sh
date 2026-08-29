#!/usr/bin/env bash
set -euo pipefail

root=${1:?Terraform root required}
terraform -chdir="terraform/${root}" plan -detailed-exitcode -input=false -lock-timeout=60s -out="../../test-results/${root}.tfplan" || code=$?
case ${code:-0} in
  0) printf '%s state matches configuration\n' "$root" ;;
  2) printf '%s has expected unapplied changes\n' "$root" ;;
  *) exit "${code}" ;;
esac
