# ADR 0006: workload identity

**Decision:** use GitHub WIF for pipelines and GKE Workload Identity for Pods. No
service-account key is supported. Separate API, worker, build, deploy, node, plan
and apply identities keep trust boundaries reviewable.
