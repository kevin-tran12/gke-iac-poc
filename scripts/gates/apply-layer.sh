#!/usr/bin/env bash
set -eEuo pipefail

layer=${1:?layer required}
profile=${2:-core}
source scripts/gates/common.sh
validate_layer "$layer"
(( layer > 0 )) || { printf 'layer 0 has no cloud apply\n' >&2; exit 2; }
require_clean_tree
bash scripts/gates/check-prerequisites.sh "$layer"
mkdir -p test-results/live
prepare_layer "$layer" "$profile"
root=$LAYER_ROOT
plan_path=$(plan_path_for_layer "$layer")
manifest_path=$(manifest_path_for_layer "$layer")

if [[ ! -s $plan_path || ! -s $manifest_path ]] && [[ -n "${PLAN_STORE_URI:-}" ]]; then
  remote="${PLAN_STORE_URI%/}/layer-${layer}/$(git rev-parse HEAD)"
  gcloud storage cp "${remote}/${root}.tfplan" "$plan_path" >/dev/null
  gcloud storage cp "${remote}/${root}.plan.json" "$manifest_path" >/dev/null
fi
bash scripts/gates/validate-plan.sh "$layer" "$profile" "$plan_path" "$manifest_path"
plan_digest=$(sha256sum "$plan_path" | cut -d' ' -f1)

export PLAN_DIGEST=$plan_digest PLAN_MANIFEST=$manifest_path AFFECTED_ROOTS
if (( layer >= 2 )); then
  bash scripts/gates/create-lease.sh
fi

applied=false
record_failure() {
  local code=$?
  if [[ $applied != true && $code -ne 0 ]]; then
    terraform -chdir="terraform/${root}" state list >"test-results/live/layer-${layer}-partial-state.txt" 2>&1 || true
    bash scripts/gates/record-result.sh "$layer" failed || true
  fi
  exit "$code"
}
trap record_failure EXIT

terraform -chdir="terraform/${root}" apply -input=false "../../${plan_path}"
if (( layer == 1 )); then
  refresh_bootstrap_outputs
fi
bash scripts/gates/record-result.sh "$layer" applied
if [[ -n "${PLAN_STORE_URI:-}" ]]; then
  remote="${PLAN_STORE_URI%/}/layer-${layer}/$(git rev-parse HEAD)"
  gcloud storage rm "${remote}/${root}.tfplan" "${remote}/${root}.plan.json" >/dev/null 2>&1 || true
fi
applied=true
trap - EXIT
printf 'Layer %s was applied from the reviewed plan. Run: make verify-layer LAYER=%s PROFILE=%s\n' "$layer" "$layer" "$profile"
