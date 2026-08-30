# Bottom-up build order

| Gate | Creates | Required proof | Approval |
| --- | --- | --- | --- |
| 0 | Dev Container and toolchain | Versions, tests, lint, Terraform format, manifests and diagrams | Automatic |
| 1 | Project, APIs, budget, state and WIF | Keyless access works; excess access is denied | `foundation` |
| 2 | VPC and subnet | Non-overlapping ranges, PGA, Flow Logs and stable plan | `foundation` |
| 3 | Registry, build, Pub/Sub, GCS and secrets | Build/pull, publish/receive, precondition and IAM tests | `foundation` |
| 4 | Private GKE | DNS endpoint, Ready nodes, WIF, Dataplane V2, no public node IP | `cluster` |
| 5 | Policies and observability | Default deny, required allowed flows, healthy webhooks, telemetry | `cluster` |
| 6 | Internal workloads | ClusterIP routing, hostname variation, HPA, readiness and PVC persistence | `cluster` |
| 7 | Signed staging delivery | Cloud Build tests/SBOM/provenance, KMS attestation, verified rollout and durable job journey | `delivery` |
| 8 | Gateway/TLS/Armor | HTTPS, redirect, routes, headers, WAF and rate limiting | `delivery` |
| 9 | Optional recovery profile | Cost/TTL recorded; Backup for GKE restores the exact Persistent Disk proof | `recovery` |

Production promotion is a separate protected workflow after the layer 7 staging
verification succeeds. Failure labs and runtime teardown use
`destructive-labs`; the separately confirmed project deletion uses
`final-delete`. They do not masquerade as successful provisioning gates.

Gate records retain the producing commit for auditability and bind proof to a
cumulative source digest, all affected state lineages and serials, plan digest,
profile, test result, creation time, and expiry time. Only `verified` proof can
unlock a downstream layer. `planned`, `applied`, `failed`, `destroyed`, unrelated,
legacy, expired, and source-stale records are rejected.

Layer-specific live tests are fingerprinted separately. Changing a later live
test does not invalidate an earlier layer, while shared orchestration and an
upstream contract still invalidate every affected downstream gate.
