#!/usr/bin/env bash
set -euo pipefail

target=${1:?target layer required}
profile=${2:-core}
(( target >= 2 && target <= 9 )) || { printf 'target must be 2-9\n' >&2; exit 2; }
if (( target == 9 )) && [[ $profile != recovery ]]; then
  printf 'layer 9 requires PROFILE=recovery\n' >&2
  exit 2
fi

# Tooling and project bootstrap are one-time prerequisites. Their gate records
# are checked by layer 2; live project workflows never recreate either layer.
for ((layer=2; layer<=target; layer++)); do
  layer_profile=core
  if (( layer == 2 && target >= 8 )); then
    layer_profile=egress
  elif (( layer == 2 )) && [[ $profile == egress ]]; then
    layer_profile=egress
  elif (( layer == 3 )) && [[ $profile == data ]]; then
    layer_profile=data
  elif (( layer == 4 )) && [[ $profile == ha || $profile == recovery ]]; then
    layer_profile=$profile
  elif (( layer == 9 )); then
    layer_profile=recovery
  fi
  bash scripts/gates/run-layer.sh "$layer" "$layer_profile"
done
