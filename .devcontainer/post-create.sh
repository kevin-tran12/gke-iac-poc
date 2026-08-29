#!/usr/bin/env bash
set -euo pipefail

if ! git config --global --get-all safe.directory | grep -Fxq "$PWD"; then
  git config --global --add safe.directory "$PWD"
fi

cache_dirs=(
  /home/vscode/.config/gh
  /home/vscode/.config/gcloud
  /home/vscode/.gnupg
  /home/vscode/.cache/go-build
  /home/vscode/go/pkg/mod
  /home/vscode/.cache/trivy
  /home/vscode/.tflint.d
  /home/vscode/.terraform.d/plugin-cache
)
for cache_dir in "${cache_dirs[@]}"; do
  sudo chown "$(id -u):$(id -g)" "$cache_dir"
done

printf 'Terraform: %s\n' "$(terraform version -json | jq -r .terraform_version)"
printf 'Go: %s\n' "$(go version)"
printf 'kubectl: %s\n' "$(kubectl version --client -o json | jq -r .clientVersion.gitVersion)"
printf 'Helm: %s\n' "$(helm version --short)"
printf 'gcloud: %s\n' "$(gcloud version --format=json | jq -r '."Google Cloud SDK"')"
printf '\nRun make validate before provisioning any layer.\n'
