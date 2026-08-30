#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer number required}
roots=(tooling bootstrap network platform cluster addons workloads delivery edge recovery)
(( layer >= 0 && layer < ${#roots[@]} )) || { printf 'layer must be 0-9\n' >&2; exit 2; }
root=${roots[$layer]}

printf 'Running local/CI parity checks for layer %02d (%s)\n' "$layer" "$root"

if (( layer == 0 )); then
  unformatted=$(gofmt -l app tests)
  test -z "$unformatted" || { printf 'Go files need gofmt:\n%s\n' "$unformatted" >&2; exit 1; }
  (cd app && go vet ./... && go test -race ./...)
  (cd tests && go vet ./... && go test ./...)
  terraform fmt -check -recursive terraform
  kubectl kustomize deploy/overlays/staging >/dev/null
  kubectl kustomize deploy/overlays/production >/dev/null
  kubectl kustomize deploy/overlays/data >/dev/null
  find scripts tests/labs .githooks -type f -name '*.sh' -print0 | xargs -0 -r shellcheck
  bash tests/gates/evidence-workflow.sh
  bash scripts/check-docs.sh
  exit 0
fi

terraform_root="terraform/${root}"
terraform -chdir="$terraform_root" fmt -check -recursive
terraform -chdir="$terraform_root" init -backend=false -input=false
terraform -chdir="$terraform_root" validate
terraform -chdir="$terraform_root" test
go test ./tests/gates -run "TestLayer$(printf '%02d' "$layer")" -v

case "$layer" in
  3)
    grep -q 'requestedVerifyOption: VERIFIED' cloudbuild.yaml
    ;;
  6)
    kubectl kustomize deploy/overlays/staging >/dev/null
    ;;
  7)
    (cd app && go test -race ./...)
    ;;
  9)
    find tests/labs -type f -name '*.sh' -print0 | xargs -0 -r shellcheck
    ;;
esac
