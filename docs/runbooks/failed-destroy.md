# Runbook: failed destroy

Keep the project and state bucket. Identify the exact root and resource, inspect
dependency/finalizer/audit events, and retry reverse-order destroy. For Kubernetes
finalizers, confirm the controller is healthy before removal. Never delete state
to hide a live resource. Finish with `verify-no-billable-resources.sh`.
