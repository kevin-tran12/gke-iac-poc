#!/usr/bin/env bash
set -euo pipefail

install_dir=${1:-"$HOME/.local/bin"}
mkdir -p "$install_dir"

go_binary=$(command -v go || true)
if [[ -z $go_binary && -x /usr/local/go/bin/go ]]; then
  go_binary=/usr/local/go/bin/go
fi
test -n "$go_binary" || { printf 'Go is required to install security tools\n' >&2; exit 127; }

export GOBIN=$install_dir
"$go_binary" install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
"$go_binary" install github.com/zricethezav/gitleaks/v8@v8.28.0
"$go_binary" install golang.org/x/vuln/cmd/govulncheck@v1.7.0
"$go_binary" install github.com/yannh/kubeconform/cmd/kubeconform@v0.7.0
"$go_binary" install github.com/terraform-linters/tflint@v0.64.0

trivy_version=0.72.0
trivy_sha256=bbb64b9695866ce4a7a8f5c9592002c5961cab378577fa3f8a040df362b9b2ea
temporary_dir=$(mktemp -d)
cleanup() { rm -rf "$temporary_dir"; }
trap cleanup EXIT
archive="$temporary_dir/trivy.tar.gz"
curl -fsSLo "$archive" "https://github.com/aquasecurity/trivy/releases/download/v${trivy_version}/trivy_${trivy_version}_Linux-64bit.tar.gz"
printf '%s  %s\n' "$trivy_sha256" "$archive" | sha256sum --check --strict -
tar -xzf "$archive" -C "$temporary_dir" trivy
install -m 0755 "$temporary_dir/trivy" "$install_dir/trivy"

printf 'Installed security tools in %s\n' "$install_dir"
