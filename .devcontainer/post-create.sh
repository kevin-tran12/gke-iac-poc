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
chmod 700 /home/vscode/.gnupg
find /home/vscode/.gnupg -type d -exec chmod 700 {} +
find /home/vscode/.gnupg -type f -exec chmod 600 {} +

printf 'Terraform: %s\n' "$(terraform version -json | jq -r .terraform_version)"
printf 'Go: %s\n' "$(go version)"
printf 'kubectl: %s\n' "$(kubectl version --client -o json | jq -r .clientVersion.gitVersion)"
printf 'Helm: %s\n' "$(helm version --short)"
printf 'gcloud: %s\n' "$(gcloud version --format=json | jq -r '."Google Cloud SDK"')"
bash scripts/check-devcontainer.sh --setup
printf '\nRun bash scripts/check-devcontainer.sh --require-auth before provisioning, then make validate.\n'
