#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer required}
(( layer >= 1 && layer <= 9 )) || { printf 'layer must be 1-9\n' >&2; exit 2; }

# Each gate fingerprints its own inputs plus every upstream layer. A change to
# an upstream contract therefore invalidates downstream evidence, while a
# change to a later layer leaves earlier proof reusable.
paths=(
  scripts/gates/check-prerequisites.sh
  scripts/gates/layer-source-digest.sh
  scripts/gates/record-result.sh
  scripts/gates/run-layer.sh
  scripts/gates/test-live-layer.sh
  scripts/gates/verify-layer-state.sh
)

(( layer >= 1 )) && paths+=(terraform/bootstrap scripts/migrate-state.sh)
(( layer >= 2 )) && paths+=(terraform/network terraform/profiles/egress.tfvars)
(( layer >= 3 )) && paths+=(terraform/platform terraform/profiles/data.tfvars scripts/mirror-public-images.sh docs/public-test-images.md)
(( layer >= 4 )) && paths+=(terraform/cluster terraform/profiles/core.tfvars terraform/profiles/ha.tfvars terraform/profiles/recovery.tfvars)
(( layer >= 5 )) && paths+=(terraform/addons)
(( layer >= 6 )) && paths+=(terraform/workloads deploy/base deploy/overlays)
(( layer >= 7 )) && paths+=(terraform/delivery app cloudbuild.yaml deploy/skaffold.yaml scripts/build-release.sh)
(( layer >= 8 )) && paths+=(terraform/edge)
(( layer >= 9 )) && paths+=(terraform/recovery tests/labs/persistent-disk-restore.sh)

git ls-files -z -- "${paths[@]}" |
  sort -z |
  while IFS= read -r -d '' file; do
    printf '%s\0%s\0' "$file" "$(git hash-object "$file")"
  done |
  sha256sum |
  cut -d' ' -f1
