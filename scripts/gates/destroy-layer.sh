#!/usr/bin/env bash
set -euo pipefail

layer=${1:?layer required}
profile=${2:-core}
source scripts/gates/common.sh
validate_layer "$layer"
(( layer >= 2 )) || { printf 'use the dedicated final-delete process for bootstrap; layer 0 has nothing to destroy\n' >&2; exit 2; }
test "${CONFIRM_DESTROY:-}" = "layer-${layer}" || {
  printf 'set CONFIRM_DESTROY=layer-%s to destroy this layer\n' "$layer" >&2
  exit 2
}
require_clean_tree
prepare_layer "$layer" "$profile"
root=$LAYER_ROOT

for ((downstream=layer+1; downstream<=9; downstream++)); do
  record=.gate-state/layer-${downstream}.json
  if [[ -s $record ]] && [[ $(jq -r .status "$record") != destroyed ]]; then
    printf 'destroy layer %s first; runtime teardown must proceed in reverse order\n' "$downstream" >&2
    exit 1
  fi
done

mapfile -t profile_args < <(profile_arguments "$root" "$profile")
destroy_plan="test-results/live/${root}-destroy.tfplan"
terraform -chdir="terraform/${root}" plan -destroy -input=false -lock-timeout=120s \
  "${profile_args[@]}" -out="../../${destroy_plan}"
terraform -chdir="terraform/${root}" apply -input=false "../../${destroy_plan}"
PLAN_DIGEST="$(sha256sum "$destroy_plan" | cut -d' ' -f1)"
export PLAN_DIGEST
bash scripts/gates/record-result.sh "$layer" destroyed
printf 'Layer %s was destroyed. Verify the cloud inventory before deleting another layer.\n' "$layer"
