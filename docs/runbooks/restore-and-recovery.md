# Runbook: restore and recovery

Record the proof file and backup ID before deletion. Confirm backup completion and
RestorePlan scope (`test`, no Secrets). Restore into the same ephemeral cluster,
wait for PVC/StatefulSet readiness, compare the exact proof value, collect events,
and destroy backups/plans after evidence. A Kubernetes object existing without the
durable value is a failed restore.
