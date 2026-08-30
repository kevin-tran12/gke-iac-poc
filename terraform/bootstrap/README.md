# Layer 1: bootstrap

This is the only root that starts with local state. It creates or adopts the lab
project, enables the profile-specific API allowlist, installs the $75 alerting
budget, protects the remote-state bucket, enables targeted audit logs, and
configures repository-bound GitHub federation.

GitHub receives four keyless phase identities:

| Identity | Layers | Protected environments |
| --- | --- | --- |
| Foundation | 1–3 | `foundation` |
| Cluster | 4–6 | `cluster` |
| Delivery | 7–8 and promotion | `delivery`, `production` |
| Recovery | 9 and cleanup | `recovery`, `automated-reaper`, `destructive-labs`, `final-delete` |

The WIF provider requires the immutable repository and owner IDs, `main`, the
reviewed caller workflow, the pinned reusable workflow, and an expected GitHub
environment. The service-account bindings then map each environment to only its
phase identity. Changing any workflow filename or environment requires an
intentional Terraform change.

`bootstrap_profile=core` omits optional Cloud SQL, delivery, Binary
Authorization, KMS, and Backup APIs. The selected portfolio demonstration uses
`PROFILE=full`; API enablement itself is not the spending control—resource
profiles, quotas, the four-hour lease, and teardown provide that boundary.

For an existing project, run `scripts/adopt-project.sh` before import. It refuses
to import until the active project, billing account, and organization placement
match the operator's explicit values. Initial creation or adoption uses user ADC;
normal GitHub operations remain keyless.

The same initial operator step grants Foundation the narrow Billing Account User
and Costs Manager roles. No GitHub identity can edit billing-account IAM. Removing
those trust-anchor bindings after final project deletion therefore remains an
explicit billing-account operator cleanup step.

Policy Troubleshooter must read IAM deny policies inherited from the organization
to return conclusive `CAN_ACCESS` results. For an organization-owned project, an
organization administrator performs this one-time prerequisite after the
Foundation service account exists:

```bash
PROJECT_ID=$(terraform -chdir=terraform/bootstrap output -raw project_id)
ORGANIZATION_ID=$(gcloud projects get-ancestors "$PROJECT_ID" --format=json |
  jq -r '.[] | select(.type == "organization") | .id')
OPERATOR_ACCOUNT=$(gcloud auth list --filter='status:ACTIVE' --format='value(account)')
FOUNDATION_ACCOUNT=$(terraform -chdir=terraform/bootstrap output -raw terraform_foundation_service_account)

gcloud organizations add-iam-policy-binding "$ORGANIZATION_ID" \
  --member="user:${OPERATOR_ACCOUNT}" --role=roles/iam.denyReviewer --condition=None
gcloud organizations add-iam-policy-binding "$ORGANIZATION_ID" \
  --member="serviceAccount:${FOUNDATION_ACCOUNT}" --role=roles/iam.denyReviewer --condition=None
```

`roles/iam.denyReviewer` is read-only. The operator needs it for local live gates,
and Foundation needs it for the protected GitHub gate. These bindings are an
explicit organization bootstrap prerequisite rather than project Terraform
resources: allowing Foundation to manage organization IAM solely to maintain its
own reader binding would violate the phase boundary. Remove both bindings during
the final organization cleanup if they are no longer needed.

Use `terraform.tfvars.example`, never commit its populated copy, and run
`scripts/migrate-state.sh` only after the first verified Gate 1. The migration
creates an ignored `backend.tf` because the bucket cannot be a backend until it
exists. The bucket uses uniform access, public-access prevention, versioning,
seven-day soft deletion, `force_destroy=false`, and Terraform deletion
prevention.

Normal teardown retains this root. Only the separate `final-delete.yml` workflow,
its protected environment, and an exact project-ID confirmation may remove the
state bucket, unlink billing, and request project deletion.
