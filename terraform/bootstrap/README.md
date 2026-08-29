# Layer 1: bootstrap

This is the only root that starts with local state. It creates the disposable
project, enables the API allowlist, installs a budget, creates the versioned GCS
state bucket, and configures repository-bound GitHub OIDC federation. The WIF
provider verifies immutable repository and owner IDs. Read-only planning is
repository-scoped, while apply impersonation is limited to an explicit workflow
allowlist at `refs/heads/main`; protected GitHub environments add the human
approval boundary. Adding or renaming a live workflow therefore requires an
intentional update to `local.apply_workflow_refs`.

Use `terraform.tfvars.example`, never commit its populated copy, and run
`scripts/migrate-state.sh` after the first successful apply and Gate 01 result.
The migration script creates an ignored local `backend.tf` that switches this
root to the new GCS backend; the bucket and backend cannot be configured before
bootstrap creates them. Destroy this root only after all other roots and state
objects are gone.
