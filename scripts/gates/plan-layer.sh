#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer required}
profile=${2:-core}
source scripts/gates/common.sh
validate_layer "$layer"

bash scripts/ci/test-layer.sh "$layer"
if (( layer == 0 )); then
  PROFILE=$profile bash scripts/gates/record-result.sh 0 verified
  printf 'Layer 0 has no cloud plan; local verification passed.\n'
  exit 0
fi

bash scripts/gates/check-prerequisites.sh "$layer"
mkdir -p test-results/live
prepare_layer "$layer" "$profile"
root=$LAYER_ROOT
plan_path=$(plan_path_for_layer "$layer")
manifest_path=$(manifest_path_for_layer "$layer")
mapfile -t profile_args < <(profile_arguments "$root" "$profile")

if (( layer == 1 )); then
  terraform -chdir=terraform/bootstrap plan -input=false -lock-timeout=60s \
    -var-file="$BOOTSTRAP_TFVARS" -out="../../${plan_path}"
else
  terraform -chdir="terraform/${root}" plan -input=false -lock-timeout=60s \
    "${profile_args[@]}" -out="../../${plan_path}"
fi

plan_digest=$(sha256sum "$plan_path" | cut -d' ' -f1)
input_digest=$(layer_input_digest "$layer" "$profile")
source_digest=$(bash scripts/gates/layer-source-digest.sh "$layer")
created=$(date -u +%FT%TZ)
expires=$(date -u -d "+${PLAN_TTL_HOURS:-4} hours" +%FT%TZ)
read -r -a affected_root_names <<<"$AFFECTED_ROOTS"
affected_roots=$(printf '%s\n' "${affected_root_names[@]}" | jq -R . | jq -s .)

jq -n \
  --argjson schema_version 1 \
  --argjson layer "$layer" \
  --arg root "$root" \
  --arg profile "$profile" \
  --arg commit_sha "$(git rev-parse HEAD)" \
  --arg source_digest "$source_digest" \
  --arg input_digest "$input_digest" \
  --arg plan_digest "$plan_digest" \
  --arg plan_path "$plan_path" \
  --arg created_at "$created" \
  --arg expires_at "$expires" \
  --argjson affected_roots "$affected_roots" \
  '{schema_version:$schema_version,layer:$layer,root:$root,profile:$profile,commit_sha:$commit_sha,source_digest:$source_digest,input_digest:$input_digest,plan_digest:$plan_digest,plan_path:$plan_path,affected_roots:$affected_roots,created_at:$created_at,expires_at:$expires_at}' \
  >"$manifest_path"

export PLAN_DIGEST=$plan_digest PLAN_MANIFEST=$manifest_path AFFECTED_ROOTS
bash scripts/gates/record-result.sh "$layer" planned

if [[ -n "${PLAN_STORE_URI:-}" ]]; then
  gcloud storage cp "$plan_path" "$manifest_path" "${PLAN_STORE_URI%/}/layer-${layer}/$(git rev-parse HEAD)/" >/dev/null
fi

printf 'Saved reviewed-plan candidate: %s\nManifest: %s\n' "$plan_path" "$manifest_path"
printf 'After reviewing it, run: make apply-layer LAYER=%s PROFILE=%s\n' "$layer" "$profile"
