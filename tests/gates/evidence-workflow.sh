#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"
temporary_dir=$(mktemp -d)
cleanup() { rm -rf "$temporary_dir"; }
trap cleanup EXIT

export GATE_STATE_DIR="$temporary_dir/gates"
export EVIDENCE_DIR="$temporary_dir/evidence"
export RECORD_ONLY_LOCAL=true
export PROFILE=core
export AFFECTED_ROOTS=

bash scripts/gates/record-result.sh 0 planned
test -s "$GATE_STATE_DIR/layer-0-planned.json"
test ! -e "$GATE_STATE_DIR/layer-0.json"
jq -e '.schema_version == 2 and .status == "planned" and .terraform_states == []' \
  "$GATE_STATE_DIR/layer-0-planned.json" >/dev/null

bash scripts/gates/record-result.sh 0 verified
jq -e '.schema_version == 2 and .status == "verified"' \
  "$GATE_STATE_DIR/layer-0.json" >/dev/null

set +e
APPLY=true bash scripts/gates/run-layer.sh 0 core >"$temporary_dir/run-layer.out" 2>&1
code=$?
set -e
test "$code" -eq 2
grep -Fq 'APPLY=true is no longer supported' "$temporary_dir/run-layer.out"

plan="$temporary_dir/tooling.tfplan"
manifest="$temporary_dir/tooling.plan.json"
printf 'reviewed plan\n' >"$plan"
plan_digest=$(sha256sum "$plan" | cut -d' ' -f1)
source_digest=$(bash scripts/gates/layer-source-digest.sh 0)
input_digest=$(source scripts/gates/common.sh; layer_input_digest 0 core)
jq -n \
  --argjson schema_version 1 \
  --argjson layer 0 \
  --arg root tooling \
  --arg profile core \
  --arg plan_path "$plan" \
  --arg commit_sha "$(git rev-parse HEAD)" \
  --arg source_digest "$source_digest" \
  --arg input_digest "$input_digest" \
  --arg plan_digest "$plan_digest" \
  --arg expires_at "$(date -u -d '+1 hour' +%FT%TZ)" \
  '{schema_version:$schema_version,layer:$layer,root:$root,profile:$profile,plan_path:$plan_path,commit_sha:$commit_sha,source_digest:$source_digest,input_digest:$input_digest,plan_digest:$plan_digest,expires_at:$expires_at}' \
  >"$manifest"
bash scripts/gates/validate-plan.sh 0 core "$plan" "$manifest"
printf 'tampered\n' >>"$plan"
if bash scripts/gates/validate-plan.sh 0 core "$plan" "$manifest" >"$temporary_dir/tamper.out" 2>&1; then
  printf 'tampered saved plan was accepted\n' >&2
  exit 1
fi
grep -Fq 'saved plan digest does not match its manifest' "$temporary_dir/tamper.out"
