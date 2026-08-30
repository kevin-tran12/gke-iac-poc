#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer required}
status=${2:?status required}
case "$status" in
  planned|applied|verified|failed|destroyed) ;;
  *) printf 'invalid gate status: %s\n' "$status" >&2; exit 2 ;;
esac

gate_state_dir=${GATE_STATE_DIR:-.gate-state}
evidence_dir=${EVIDENCE_DIR:-test-results/live}
mkdir -p "$gate_state_dir" "$evidence_dir"
created=$(date -u +%FT%TZ)
if [[ -s "$gate_state_dir/environment-lease.json" ]]; then
  expires=$(jq -er .expires_at "$gate_state_dir/environment-lease.json")
else
  expires=$(date -u -d "+${ENVIRONMENT_TTL_HOURS:-4} hours" +%FT%TZ)
fi
plan_digest=${PLAN_DIGEST:-not-applicable}
source_digest=$(bash scripts/gates/layer-source-digest.sh "$layer")
plan_manifest=${PLAN_MANIFEST:-}
read -r -a affected_roots <<<"${AFFECTED_ROOTS:-}"

terraform_states='[]'
for root in "${affected_roots[@]}"; do
  [[ -d "terraform/${root}" ]] || continue
  if snapshot=$(terraform -chdir="terraform/${root}" state pull 2>/dev/null |
      jq -c --arg root "$root" '{root:$root,lineage:.lineage,serial:.serial}'); then
    terraform_states=$(jq -c --argjson snapshot "$snapshot" '. + [$snapshot]' <<<"$terraform_states")
  else
    if [[ $status == applied || $status == verified ]]; then
      printf 'cannot publish %s evidence without a state fingerprint for %s\n' "$status" "$root" >&2
      exit 1
    fi
    terraform_states=$(jq -c --arg root "$root" '. + [{root:$root,state_available:false}]' <<<"$terraform_states")
  fi
done

affected_roots_json=$(printf '%s\n' "${affected_roots[@]}" | jq -R 'select(length > 0)' | jq -s .)
record="$gate_state_dir/layer-${layer}.json"
if [[ $status == planned ]]; then
  record="$gate_state_dir/layer-${layer}-planned.json"
fi

jq -n \
  --argjson schema_version 2 \
  --argjson layer "$layer" \
  --arg status "$status" \
  --arg commit_sha "$(git rev-parse HEAD)" \
  --arg profile "${PROFILE:-core}" \
  --arg created_at "$created" \
  --arg expires_at "$expires" \
  --arg plan_digest "$plan_digest" \
  --arg plan_manifest "$plan_manifest" \
  --arg source_digest "$source_digest" \
  --argjson affected_roots "$affected_roots_json" \
  --argjson terraform_states "$terraform_states" \
  '{schema_version:$schema_version,layer:$layer,status:$status,commit_sha:$commit_sha,source_digest:$source_digest,profile:$profile,created_at:$created_at,expires_at:$expires_at,plan_digest:$plan_digest,plan_manifest:$plan_manifest,affected_roots:$affected_roots,terraform_states:$terraform_states}' \
  >"$record"

evidence="$evidence_dir/layer-${layer}-${status}-gate.json"
cp "$record" "$evidence"

if [[ $status != planned && -n "${TF_STATE_BUCKET:-}" && "${RECORD_ONLY_LOCAL:-false}" != true ]]; then
  gcloud storage cp "$record" "gs://${TF_STATE_BUCKET}/gates/layer-${layer}.json" >/dev/null
fi
