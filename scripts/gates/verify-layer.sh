#!/usr/bin/env bash
set -eEuo pipefail

layer=${1:?layer required}
profile=${2:-core}
source scripts/gates/common.sh
validate_layer "$layer"
(( layer > 0 )) || exec bash scripts/ci/test-layer.sh 0
require_clean_tree
prepare_layer "$layer" "$profile"
root=$LAYER_ROOT
record=.gate-state/layer-${layer}.json
if [[ ! -s $record && -n "${TF_STATE_BUCKET:-}" ]]; then
  mkdir -p .gate-state
  gcloud storage cp "gs://${TF_STATE_BUCKET}/gates/layer-${layer}.json" "$record" >/dev/null
fi
test -s "$record" || { printf 'layer %s has no applied gate record\n' "$layer" >&2; exit 1; }
status=$(jq -r .status "$record")
[[ $status == applied || $status == verified ]] || {
  printf 'layer %s must be applied before verification; current status is %s\n' "$layer" "$status" >&2
  exit 1
}
test "$(jq -r .profile "$record")" = "$profile" || {
  printf 'applied evidence belongs to profile %s, not %s\n' "$(jq -r .profile "$record")" "$profile" >&2
  exit 1
}
test "$(jq -r .commit_sha "$record")" = "$(git rev-parse HEAD)" || {
  printf 'applied evidence belongs to a different commit\n' >&2
  exit 1
}

verified=false
record_failure() {
  local code=$?
  if [[ $verified != true && $code -ne 0 ]]; then
    bash scripts/gates/record-result.sh "$layer" failed || true
  fi
  exit "$code"
}
trap record_failure EXIT

if (( layer == 1 )); then
  refresh_bootstrap_outputs
fi
export PROFILE=$profile
bash scripts/gates/test-live-layer.sh "$layer" "$profile"
mapfile -t profile_args < <(profile_arguments "$root" "$profile")
drift_plan="test-results/live/${root}-drift.tfplan"
set +e
if (( layer == 1 )); then
  terraform -chdir=terraform/bootstrap plan -detailed-exitcode -input=false -lock-timeout=60s \
    -var-file="$BOOTSTRAP_TFVARS" -var="bootstrap_profile=${profile}" -out="../../${drift_plan}"
else
  terraform -chdir="terraform/${root}" plan -detailed-exitcode -input=false -lock-timeout=60s \
    "${profile_args[@]}" -out="../../${drift_plan}"
fi
code=$?
set -e
case $code in
  0) ;;
  2) printf 'post-apply drift detected for layer %s\n' "$layer" >&2; exit 1 ;;
  *) exit "$code" ;;
esac

PLAN_DIGEST="$(jq -r .plan_digest "$record")"
PLAN_MANIFEST="$(jq -r '.plan_manifest // empty' "$record")"
export PLAN_DIGEST PLAN_MANIFEST
bash scripts/gates/record-result.sh "$layer" verified
verified=true
trap - EXIT
printf 'Layer %s live tests passed and Terraform reports no drift.\n' "$layer"
