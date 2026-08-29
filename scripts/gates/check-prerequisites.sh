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
test "$(jq -r .commit_sha "$record")" = "$(git rev-parse HEAD)"
expires=$(jq -r .expires_at "$record")
expires_epoch=$(date -u -d "$expires" +%s)
now_epoch=$(date -u +%s)
(( expires_epoch > now_epoch )) || { printf 'prerequisite gate has expired\n' >&2; exit 1; }
