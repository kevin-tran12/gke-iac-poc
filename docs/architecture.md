# Architecture

## Design objective

The system is a disposable cloud-engineering laboratory. It demonstrates a
secure platform and a credible operational lifecycle, not continuous product
availability. Google Cloud hosts the runtime; GitHub contains the durable design,
code, sanitized evidence, and incident history.

## Resource and state boundaries

Terraform roots are deliberately ordered:

1. `bootstrap`: project, APIs, budget, state bucket, GitHub WIF.
2. `network`: VPC, private subnet, overlap-checked Pod/Service/Private Service Access ranges, Private Google Access, optional NAT.
3. `platform`: registry, build identity, Pub/Sub, GCS, secrets, optional SQL.
4. `cluster`: private GKE, node pools, Workload Identity, Dataplane V2.
5. `addons`: cert-manager and OpenTelemetry.
6. `workloads`: namespaces, policies, public test workloads, recovery PVC.
7. `delivery`: Cloud Deploy, KMS attestor, Binary Authorization policy.
8. `edge`: address, Gateway, TLS, Cloud Armor, routes.
9. `recovery`: Backup for GKE and restore plan.

The boundaries prevent Kubernetes providers from initializing before GKE exists,
keep public and paid services approval-gated, and make reverse-order teardown
deterministic. Cloud Deploy owns Go application Deployments; Terraform owns
namespaces, policy, add-ons, infrastructure, and test workloads.

## Application data flow

1. The authenticated API validates a maximum 4 KiB synthetic payload.
2. It creates a UUID and publishes the versioned message to Pub/Sub.
3. The worker obtains a non-sensitive salt from Secret Manager through GKE
   Workload Identity and computes a deterministic digest.
4. It creates `results/<job-id>.json` in GCS with a `DoesNotExist` precondition.
5. Duplicate delivery observes the existing object and acknowledges without a
   second logical result.
6. The optional data profile upserts audit/status metadata into private Cloud SQL
   using the Cloud SQL Go Connector and automatic IAM database authentication.
7. Logs, metrics, and traces flow to Google Cloud Observability through the
   OpenTelemetry Collector without recording payloads or credentials.

## External request flow

`client -> nip.io DNS -> global IP -> Cloud Armor -> GKE Gateway -> Service -> Pod`

HTTP redirects to HTTPS. cert-manager completes Let's Encrypt HTTP-01 through the
Gateway. `/echo`, `/hello`, and the API route to separate Services. Cross-namespace
backends require explicit ReferenceGrants. `nip.io` supplies temporary DNS only;
it does not host the service.

## Scaling model

The one-node on-demand pool hosts system components. Application Pods tolerate a
zero-to-three-node Spot pool but may fall back to the system pool. HPA uses CPU
utilization and is tested separately from node autoscaling. Replica and node caps,
load duration, and namespace quotas bound the experiment.

## Recovery model

The worker's source message remains durable until acknowledgement. GCS generation
preconditions provide idempotency. A small StatefulSet proves Persistent Disk
backup and restore. The SQL profile proves automated backup and PITR. The regional
profile tests topology and PDB behavior without becoming the default deployment.

See the [service catalog](service-catalog.md), [security model](security-model.md),
and [full diagram source](diagrams/source/gcp-architecture.mmd).
