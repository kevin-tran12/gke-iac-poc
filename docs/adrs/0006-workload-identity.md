# ADR 0006: workload identity

**Decision:** use GitHub WIF for pipelines and GKE Workload Identity for Pods. No
service-account key is supported. Separate API, worker, build, deploy, node, plan
and apply identities keep trust boundaries reviewable. GitHub federation validates
immutable repository and owner IDs. The privileged apply identity additionally
trusts only reviewed deployment workflow paths on the protected `main` branch;
GitHub protected environments remain responsible for approvals.
