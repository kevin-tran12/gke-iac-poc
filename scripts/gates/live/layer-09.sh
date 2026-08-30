#!/usr/bin/env bash
set -euo pipefail
source scripts/gates/live/common.sh

test "$profile" = recovery || { printf 'layer 9 requires PROFILE=recovery\n' >&2; exit 2; }
test "$(tf_output cluster backup_agent_enabled)" = true || {
  printf 'cluster must be applied with the recovery profile first\n' >&2
  exit 1
}
BACKUP_PLAN=$(tf_output recovery backup_plan)
RESTORE_PLAN=$(tf_output recovery restore_plan)
export BACKUP_PLAN RESTORE_PLAN
export REGION=$TF_VAR_region
bash tests/labs/persistent-disk-restore.sh
