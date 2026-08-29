#!/usr/bin/env bash
set -euo pipefail

: "${TF_STATE_BUCKET:?set TF_STATE_BUCKET to the bucket created by bootstrap}"
test -s .gate-state/layer-1.json || { printf 'bootstrap gate record is missing\n' >&2; exit 1; }

backend_file=terraform/bootstrap/backend.tf
printf 'terraform {\n  backend "gcs" {}\n}\n' >"$backend_file"

terraform -chdir=terraform/bootstrap init -migrate-state -force-copy \
  -backend-config="bucket=${TF_STATE_BUCKET}" -backend-config="prefix=state/bootstrap"

gcloud storage cp .gate-state/layer-1.json "gs://${TF_STATE_BUCKET}/gates/layer-1.json" >/dev/null
printf 'Migrated bootstrap state and published the layer-1 prerequisite record.\n'
