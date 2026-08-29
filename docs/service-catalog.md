# Service catalog

| Service | Purpose | Owner/profile | Primary test | Charge or failure trigger | Cleanup |
| --- | --- | --- | --- | --- | --- |
| Resource Manager/Service Usage | Disposable project and API allowlist | bootstrap/all | API inventory | Forgotten project/API use | final project delete |
| Cloud Billing Budget | Early spend warning | bootstrap/all | budget describes project | Alert is not a hard cap | project delete |
| IAM, STS, GitHub WIF | Keyless CI/CD | bootstrap/all | OIDC succeeds; broad action denied | Bad attribute condition | bootstrap/final |
| GCS Terraform state | Isolated versioned state | bootstrap/all | state read/write and lock | Object operations/storage | final only |
| VPC and subnet | VPC-native GKE ranges | network/core | CIDR/routes/PGA | Overlap or route error | network root |
| VPC Flow Logs | Network evidence | network/core | sample query | Excess log volume | network root |
| Cloud Router/NAT | Optional public egress | network/egress | fail without, pass with NAT | Hourly/data processing | network root |
| Cloud DNS private zone | Service-discovery exercise | platform/core lab | private resolution | Per-zone/query charge | platform root |
| Artifact Registry | App and mirrored images | platform/core | digest pull | Stored images/scanning | platform root |
| Cloud Build | Tests, images, provenance | platform/core | verified build | Build minutes | platform root |
| Artifact Analysis | SBOM/vulnerability metadata | platform/core | occurrence exists | Scanning | platform root |
| Binary Authorization | Deny unattested images | delivery/core | unsigned deploy denied | Incorrect policy blocks releases | delivery + cluster toggle |
| Cloud Deploy | Staging/production progression | delivery/core | verification and approval | Active pipeline/releases | delivery root |
| GKE Standard | Kubernetes control/data plane | cluster/core | private cluster contract | Management/node uptime | cluster root |
| Compute Engine nodes | System and Spot pools | cluster/core/HA | Ready/scale/drain | VM/disk uptime | cluster root |
| GKE Gateway/load balancer | Public HTTPS | edge/core | TLS/routes/redirect | Forwarding rule and traffic | edge root |
| Cloud Armor | WAF/rate limits | edge/core | SQLi deny and 429 | Policy/rule/request count | edge root |
| cert-manager/Let's Encrypt | Temporary nip.io TLS | addons/edge | Ready certificate | ACME/DNS dependency | edge/addons roots |
| Secret Manager | API token and worker salt | platform/core | least-privilege read | Access denial/quota | platform root |
| Pub/Sub | Async work, retries and DLQ | platform/core | duplicate/redelivery | Retained bytes/operations | platform root |
| GCS results | Idempotent durable output | platform/core | generation precondition | Stored bytes/operations | platform root |
| Cloud SQL PostgreSQL | Private audit and PITR | platform/data | IAM connect/backup/PITR | Instance/storage/backups | platform root |
| Private Service Access | Cloud SQL private path | platform/data | private connection | Address/peering conflict | platform root |
| Logging/Monitoring/Trace | Operations evidence | cluster/addons | correlated signal | Unbounded telemetry | roots + exclusions |
| Managed Prometheus | K8s/application metrics | cluster/addons | HPA/dashboard query | Sample volume | cluster/addons |
| Uptime checks | External health/TLS | platform/edge | healthy and failure alert | Check volume | platform root |
| Persistent Disk | Stateful restore proof | workloads/recovery | proof file survives/reappears | Disk/snapshot storage | workloads root |
| Backup for GKE | Namespace/PV restore | recovery | restore proof | Backups/storage | recovery root |
| nip.io | Temporary wildcard DNS | external/edge | resolves static IP | Third-party outage/rate limit | edge IP removal |
