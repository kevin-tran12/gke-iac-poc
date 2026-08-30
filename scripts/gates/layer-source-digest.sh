#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer required}
(( layer >= 0 && layer <= 9 )) || { printf 'layer must be 0-9\n' >&2; exit 2; }

# Shared orchestration invalidates every live layer. Layer-specific live tests
# are separate files, so changing a later test does not invalidate earlier proof.
paths=(
  Makefile
  scripts/gates/apply-layer.sh
  scripts/gates/check-prerequisites.sh
  scripts/gates/common.sh
  scripts/gates/create-lease.sh
  scripts/gates/destroy-layer.sh
  scripts/gates/layer-source-digest.sh
  scripts/gates/plan-layer.sh
  scripts/gates/record-result.sh
  scripts/gates/run-layer.sh
  scripts/gates/test-live-layer.sh
  scripts/gates/validate-plan.sh
  scripts/gates/verify-layer.sh
  scripts/gates/live/common.sh
)

if (( layer == 0 )); then
  paths+=(
    .devcontainer
    .github/actions/setup-toolchain
    .github/workflows/ci.yml
    .github/workflows/ci-layer-00-tooling.yml
    .github/workflows/ci-security.yml
    .github/workflows/integration-layer.yml
    .github/workflows/provision-through-layer.yml
    scripts/ci
    scripts/check-devcontainer.sh
    scripts/check-docs.sh
    scripts/install-security-tools.sh
    docs/version-inventory.md
  )
fi
(( layer >= 1 )) && paths+=(terraform/bootstrap scripts/migrate-state.sh scripts/gates/live/layer-01.sh)
(( layer >= 2 )) && paths+=(terraform/network terraform/profiles/egress.tfvars scripts/gates/live/layer-02.sh)
(( layer >= 3 )) && paths+=(terraform/platform terraform/profiles/data.tfvars scripts/mirror-public-images.sh docs/public-test-images.md scripts/gates/live/layer-03.sh)
(( layer >= 4 )) && paths+=(terraform/cluster terraform/profiles/core.tfvars terraform/profiles/ha.tfvars terraform/profiles/recovery.tfvars scripts/gates/live/layer-04.sh)
(( layer >= 5 )) && paths+=(terraform/addons scripts/gates/live/layer-05.sh)
(( layer >= 6 )) && paths+=(terraform/workloads deploy/base deploy/overlays scripts/gates/live/layer-06.sh)
(( layer >= 7 )) && paths+=(terraform/delivery app cloudbuild.yaml deploy/skaffold.yaml scripts/build-release.sh scripts/gates/live/layer-07.sh)
(( layer >= 8 )) && paths+=(terraform/edge scripts/gates/live/layer-08.sh)
(( layer >= 9 )) && paths+=(terraform/recovery tests/labs/persistent-disk-restore.sh scripts/gates/live/layer-09.sh)

git ls-files -z -- "${paths[@]}" |
  sort -z |
  while IFS= read -r -d '' file; do
    printf '%s\0%s\0' "$file" "$(git hash-object "$file")"
  done |
  sha256sum |
  cut -d' ' -f1
