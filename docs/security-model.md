# Security model

## Trust boundaries

- GitHub pull requests have read-only repository permissions and no GCP token.
- Approved live workflows exchange GitHub OIDC for a short-lived service-account
  credential restricted to immutable repository identity.
- GKE nodes are private and use a dedicated least-privilege node identity.
- Kubernetes service accounts impersonate separate API and worker Google service
  accounts through Workload Identity.
- Default-deny NetworkPolicies admit only DNS, metadata, restricted Google APIs,
  telemetry, same-namespace traffic, and explicitly approved ingress.
- The global edge crosses Cloud Armor before reaching Gateway backends.
- Cloud SQL uses private IP, TLS from the Go Connector, and automatic IAM database
  authentication. No database password is stored.

Pod Security Admission is `restricted` for cert-manager, observability, staging,
production, and recovery.
The isolated `test` namespace is the explicit Baseline exception because the
legacy CPU-bound HPA demonstration listens on port 80 as root. It has no workload
identity, no service-account token, default-deny networking, quotas, and a short
TTL. Application, worker, collector, and recovery workloads drop Linux
capabilities, run as non-root, prohibit privilege escalation, set resources, and
use read-only root filesystems where their image permits. Portfolio-controlled
images are mirrored, scanned, and referenced by digest. Production application
images receive a KMS-backed attestation. Layer 7 temporarily enables enforced
admission, proves an unsigned image is denied and the signed application rolls
out, then disables enforcement so unrelated public diagnostic/chart images do
not become an undocumented availability dependency. The short-lived enforcement
window is a deliberate portfolio-lab tradeoff, not a claim of continuous policy.

The API's lab bearer token is an intentionally limited demonstration, not a
production customer identity system. Cloud Armor bounds abuse; the environment's
TTL and reaper bound exposure. Authorization headers, payloads, secret values,
signed URLs, and credentials are excluded from logs and evidence.
