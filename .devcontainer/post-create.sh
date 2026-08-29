#!/usr/bin/env bash
set -euo pipefail

if ! git config --global --get-all safe.directory | grep -Fxq "$PWD"; then
  git config --global --add safe.directory "$PWD"
fi

printf 'Terraform: %s\n' "$(terraform version -json | jq -r .terraform_version)"
printf 'Go: %s\n' "$(go version)"
printf 'kubectl: %s\n' "$(kubectl version --client -o json | jq -r .clientVersion.gitVersion)"
printf 'Helm: %s\n' "$(helm version --short)"
printf '\nRun `make validate` before provisioning any layer.\n'
