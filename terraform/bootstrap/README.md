# Layer 1: bootstrap

This is the only root that starts with local state. It creates the disposable
project, enables the API allowlist, installs a budget, creates the versioned GCS
state bucket, and configures repository-bound GitHub OIDC federation.

Use `terraform.tfvars.example`, never commit its populated copy, and run
`scripts/migrate-state.sh` after the first successful apply. Destroy this root
only after all other roots and state objects are gone.
