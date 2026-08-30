# Google Cloud API catalog

Layer 1 owns API lifecycle so every enabled service has a named consumer. The
`core` profile enables the platform foundation. The selected `full` profile adds
the paid-feature demonstrations; enabling an API does not itself cap or approve
resource spend.

| API | Layer | Profile | Consumer |
| --- | ---: | --- | --- |
| Artifact Registry | 3 | core | Mirrored and application images |
| Billing Budgets / Cloud Billing | 1 | core | Budget alerts and billing association |
| Cloud Resource Manager | 1 | core | Project lifecycle and IAM |
| Compute Engine | 2 | core | VPC and GKE networking |
| Kubernetes Engine | 4 | core | GKE control plane |
| Cloud DNS | 3 | core | Private service discovery |
| IAM / IAM Credentials / STS | 1 | core | Service accounts and keyless GitHub federation |
| Cloud Logging / Monitoring | 1 | core | Audit logs, metrics, and alerting |
| Policy Troubleshooter | 1 | core | IAM positive and negative tests |
| Pub/Sub | 3 | core | Durable job delivery |
| Secret Manager | 3 | core | Runtime secret metadata; versions stay outside Terraform |
| Service Usage | 1 | core | API lifecycle |
| Cloud Storage | 1 | core | Terraform state and durable objects |
| Cloud SQL Admin / Service Networking | 3 | full | Private data profile |
| Cloud Build / Cloud Deploy | 7 | full | Signed builds and staged promotion |
| Cloud KMS / Container Analysis / Binary Authorization | 7 | full | Attestation and admission demonstration |
| Backup for GKE | 9 | full | Backup and restore demonstration |

The Terraform source of truth is `local.service_catalog` in
`terraform/bootstrap/main.tf`; this document is the operator-readable view and
must change with it.
