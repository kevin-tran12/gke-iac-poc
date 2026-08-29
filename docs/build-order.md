# Bottom-up build order

| Gate | Creates | Required proof | Approval |
| --- | --- | --- | --- |
| 0 | Dev Container and toolchain | Versions, tests, lint, Terraform format, manifests and diagrams | Automatic |
| 1 | Project, APIs, budget, state and WIF | Keyless access works; excess access is denied | Bootstrap operator |
| 2 | VPC and subnet | Non-overlapping ranges, PGA, Flow Logs and stable plan | Automatic |
| 3 | Registry, build, Pub/Sub, GCS and secrets | Build/pull, publish/receive, precondition and IAM tests | Automatic |
| 4 | Private GKE | DNS endpoint, Ready nodes, WIF, Dataplane V2, no public node IP | Automatic |
| 5 | Policies and observability | Default deny, required allowed flows, healthy webhooks, telemetry | Automatic |
| 6 | Internal workloads | ClusterIP routing, hostname variation, HPA, readiness and PVC persistence | Automatic |
| 7 | Signed staging delivery | Cloud Build tests/SBOM/provenance, KMS attestation, verified rollout and durable job journey | Automatic |
| 8 | Gateway/TLS/Armor | HTTPS, redirect, routes, headers, WAF and rate limiting | `public-edge` |
| 9 | Optional recovery profile | Cost/TTL recorded; Backup for GKE restores the exact Persistent Disk proof | `paid-profile` |

Production promotion is a separate protected workflow after the layer 7 staging
verification succeeds. Failure labs use `destructive-labs`; runtime teardown and
final project deletion use `final-delete`. They do not masquerade as successful
provisioning gates.

Gate records retain the producing commit for auditability and bind proof to a
cumulative source digest, state serial, plan digest, profile, test result,
creation time, and expiry time. A later-layer change can reuse unchanged
upstream proof. A change to a layer or any upstream input invalidates that layer
and every downstream gate. Records from unrelated histories, legacy
commit-only records, expired records, and failed records are rejected.
