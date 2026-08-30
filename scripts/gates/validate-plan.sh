#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer required}
profile=${2:?profile required}
plan_path=${3:?saved plan path required}
manifest_path=${4:?plan manifest path required}
source scripts/gates/common.sh
validate_layer "$layer"
root=$(root_for_layer "$layer")

test -s "$plan_path" || { printf 'saved plan is missing; run make plan-layer first\n' >&2; exit 1; }
test -s "$manifest_path" || { printf 'plan manifest is missing; run make plan-layer first\n' >&2; exit 1; }
test "$(jq -r .schema_version "$manifest_path")" = 1
test "$(jq -r .layer "$manifest_path")" = "$layer"
test "$(jq -r .root "$manifest_path")" = "$root"
test "$(jq -r .profile "$manifest_path")" = "$profile"
test "$(jq -r .plan_path "$manifest_path")" = "$plan_path" || {
  printf 'plan manifest points to an unexpected path\n' >&2
  exit 1
}
test "$(jq -r .commit_sha "$manifest_path")" = "$(git rev-parse HEAD)" || {
  printf 'the saved plan was produced from a different commit\n' >&2
  exit 1
}
test "$(jq -r .source_digest "$manifest_path")" = "$(bash scripts/gates/layer-source-digest.sh "$layer")" || {
  printf 'layer source changed after planning\n' >&2
  exit 1
}
test "$(jq -r .input_digest "$manifest_path")" = "$(layer_input_digest "$layer" "$profile")" || {
  printf 'Terraform inputs changed after planning\n' >&2
  exit 1
}
plan_digest=$(sha256sum "$plan_path" | cut -d' ' -f1)
test "$(jq -r .plan_digest "$manifest_path")" = "$plan_digest" || {
  printf 'saved plan digest does not match its manifest\n' >&2
  exit 1
}
expires_epoch=$(date -u -d "$(jq -r .expires_at "$manifest_path")" +%s)
(( expires_epoch > $(date -u +%s) )) || { printf 'saved plan has expired; create a new plan\n' >&2; exit 1; }
