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

test "$(jq -r .status "$record")" = passed
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
expires=$(jq -r .expires_at "$record")
expires_epoch=$(date -u -d "$expires" +%s)
now_epoch=$(date -u +%s)
(( expires_epoch > now_epoch )) || { printf 'prerequisite gate has expired\n' >&2; exit 1; }
