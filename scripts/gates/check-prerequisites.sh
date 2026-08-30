#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer number required}
if (( layer <= 1 )); then exit 0; fi
previous=$((layer - 1))
record=".gate-state/layer-${previous}.json"

if [[ ! -f "$record" && -n "${TF_STATE_BUCKET:-}" ]]; then
  mkdir -p .gate-state
  gcloud storage cp "gs://${TF_STATE_BUCKET}/gates/layer-${previous}.json" "$record" >/dev/null
fi
test -s "$record" || { printf 'layer %s has no prerequisite gate record\n' "$layer" >&2; exit 1; }

test "$(jq -r .status "$record")" = verified || {
  printf 'layer %s prerequisite is not verified\n' "$previous" >&2
  exit 1
}
test "$(jq -r '.schema_version // 0' "$record")" -ge 2 || {
  printf 'layer %s prerequisite uses a legacy evidence schema; re-verify it\n' "$previous" >&2
  exit 1
}
record_commit=$(jq -r .commit_sha "$record")
git merge-base --is-ancestor "$record_commit" HEAD || {
  printf 'layer %s prerequisite was not produced by an ancestor of the current commit\n' "$layer" >&2
  exit 1
}
record_digest=$(jq -r '.source_digest // empty' "$record")
current_digest=$(bash scripts/gates/layer-source-digest.sh "$previous")
test -n "$record_digest" || { printf 'layer %s prerequisite uses the legacy commit-only format; rerun layer %s\n' "$layer" "$previous" >&2; exit 1; }
test "$record_digest" = "$current_digest" || {
  printf 'layer %s prerequisite source changed; rerun layer %s and downstream gates\n' "$layer" "$previous" >&2
  exit 1
}
test "$(jq -r '.terraform_states | type' "$record")" = array || {
  printf 'layer %s prerequisite has no Terraform state fingerprints\n' "$previous" >&2
  exit 1
}
test "$(jq '.terraform_states | length' "$record")" -gt 0 || {
  printf 'layer %s prerequisite has no Terraform state fingerprints\n' "$previous" >&2
  exit 1
}

source scripts/gates/common.sh
while IFS= read -r snapshot; do
  root=$(jq -r .root <<<"$snapshot")
  expected_lineage=$(jq -r .lineage <<<"$snapshot")
  expected_serial=$(jq -r .serial <<<"$snapshot")
  if [[ $root == bootstrap && ! -f terraform/bootstrap/backend.tf ]]; then
    printf 'bootstrap state has not been migrated to the GCS backend\n' >&2
    exit 1
  fi
  init_state_root "$root"
  current=$(terraform -chdir="terraform/${root}" state pull)
  test "$(jq -r .lineage <<<"$current")" = "$expected_lineage" || {
    printf 'layer %s state lineage changed for %s; re-verify the layer\n' "$previous" "$root" >&2
    exit 1
  }
  test "$(jq -r .serial <<<"$current")" = "$expected_serial" || {
    printf 'layer %s state serial changed for %s; re-verify the layer\n' "$previous" "$root" >&2
    exit 1
  }
done < <(jq -c '.terraform_states[] | select(.state_available != false)' "$record")
expires=$(jq -r .expires_at "$record")
expires_epoch=$(date -u -d "$expires" +%s)
now_epoch=$(date -u +%s)
(( expires_epoch > now_epoch )) || { printf 'prerequisite gate has expired\n' >&2; exit 1; }
