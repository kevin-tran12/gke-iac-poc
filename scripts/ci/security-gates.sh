#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

required_tools=(actionlint gitleaks govulncheck kubeconform tflint trivy)
for tool in "${required_tools[@]}"; do
  command -v "$tool" >/dev/null || {
    printf '%s is required; run bash scripts/install-security-tools.sh /usr/local/bin\n' "$tool" >&2
    exit 127
  }
done

printf 'Checking GitHub Actions syntax and shell fragments...\n'
actionlint -color

printf 'Checking immutable external GitHub Action references...\n'
unpinned=$(rg -n --pcre2 'uses:\s+(?!\./)[^@\s]+@(?![0-9a-f]{40}(?:\s|$))' .github || true)
test -z "$unpinned" || {
  printf 'External actions must use a full commit SHA:\n%s\n' "$unpinned" >&2
  exit 1
}

printf 'Scanning committed history for secrets...\n'
gitleaks git --redact --no-banner "$repo_root"

printf 'Scanning the working tree for secrets...\n'
gitleaks dir --redact --no-banner "$repo_root"

printf 'Checking reachable Go vulnerabilities...\n'
(cd app && govulncheck -test ./...)

printf 'Initializing pinned TFLint plugins...\n'
tflint --init --config="$repo_root/.tflint.hcl"
for root in bootstrap network platform cluster addons workloads delivery edge recovery; do
  printf 'Linting terraform/%s...\n' "$root"
  tflint --chdir="$repo_root/terraform/$root" --config="$repo_root/.tflint.hcl" --format=compact
done

printf 'Validating rendered Kubernetes schemas...\n'
for overlay in staging production data; do
  kubectl kustomize "deploy/overlays/$overlay" |
    kubeconform -strict -summary -ignore-missing-schemas -kubernetes-version 1.36.0
done

printf 'Scanning IaC and Docker configuration for high-severity misconfigurations...\n'
trivy config --exit-code 1 --severity HIGH,CRITICAL --skip-version-check \
  --ignorefile "$repo_root/.trivyignore.yaml" --skip-dirs .terraform "$repo_root"
