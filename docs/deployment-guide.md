# Deployment guide

## Prerequisites

Use the Dev Container and a dedicated billing account/project choice. Obtain the
immutable numeric GitHub owner and repository IDs. Configure protected GitHub
environments and repository variables described in `docs/ci-strategy.md`.

`terraform init` performs both dependency installation and backend setup. Local
and pull-request checks deliberately run, for example,
`terraform -chdir=terraform/network init -backend=false -input=false`: this
downloads the locked providers and modules but does not contact or configure the
GCS state backend. Live workflows omit `-backend=false` and pass the exact GCS
bucket and per-layer prefix before planning. Providers are not installed by a
separate Terraform command.

Bootstrap is the only local-credential step:

```bash
cp terraform/bootstrap/terraform.tfvars.example terraform/bootstrap/terraform.auto.tfvars
export BOOTSTRAP_TFVARS="$PWD/terraform/bootstrap/terraform.auto.tfvars"
make test-layer LAYER=1
make plan-layer LAYER=1 PROFILE=full
# Review test-results/live/bootstrap.tfplan and bootstrap.plan.json.
make apply-layer LAYER=1 PROFILE=full
make verify-layer LAYER=1 PROFILE=full
export TF_STATE_BUCKET="$(terraform -chdir=terraform/bootstrap output -raw state_bucket)"
bash scripts/migrate-state.sh
```

The Dev Container persists the GPG keyring and configures a terminal-aware GPG
wrapper during post-create. After a restart, open an integrated terminal before
making a signed commit; the shell refreshes pinentry's current TTY automatically.
The agent may request the key passphrase once because passphrase caching is
in-memory and does not survive a stopped container. VS Code Source Control can
sign only after the agent has been unlocked from an interactive terminal.

If the project already exists, verify its billing and organization ownership
before importing it:

```bash
export BOOTSTRAP_TFVARS="$PWD/terraform/bootstrap/terraform.auto.tfvars"
bash scripts/adopt-project.sh PROJECT_ID BILLING_ACCOUNT ORGANIZATION_ID
```

Omit `ORGANIZATION_ID` only for a project that truly has no organization parent.

Apply layers 2 and 3, then run `scripts/mirror-public-images.sh` with reviewed source
references. This keeps public and cert-manager pulls inside Artifact Registry for
the NAT-free core profile. Add generated API token and worker salt values with
`gcloud secrets versions add`; never pass their values through Terraform.

Configure these GitHub repository variables before protected live workflows:

| Group | Variables |
| --- | --- |
| Project/WIF | `GCP_PROJECT_ID`, `GCP_PROJECT_NUMBER`, `GCP_REGION`, `TF_STATE_BUCKET`, `WIF_PROVIDER` |
| Phase identities | `TERRAFORM_FOUNDATION_SERVICE_ACCOUNT`, `TERRAFORM_CLUSTER_SERVICE_ACCOUNT`, `TERRAFORM_DELIVERY_SERVICE_ACCOUNT`, `TERRAFORM_RECOVERY_SERVICE_ACCOUNT` |
| Workloads | `ECHO_IMAGE`, `HELLO_IMAGE`, `HPA_IMAGE`, `RECOVERY_IMAGE`, `OTEL_COLLECTOR_IMAGE`, `CERT_MANAGER_IMAGES_JSON`, `LOAD_IMAGE` |
| Trusted build | `GO_BUILDER_IMAGE`, `DOCKER_BUILDER_IMAGE`, `RUNTIME_IMAGE`, `SYFT_IMAGE`, `SMOKE_IMAGE`, `VERIFIER_IMAGE` |
| Public edge | `ACME_EMAIL` |

Every image value is a reviewed Artifact Registry or trusted-builder reference
ending in `@sha256:<64 hex characters>`. Then use protected GitHub integration
workflows or the Make targets one layer at a time. Core layers 2–7 do not need
Cloud NAT; the public-edge workflow uses the egress profile so cert-manager can
reach the ACME endpoint.

Do not advance until the current layer's PR is merged and its live gate is
`verified`. Diagnose a failure with the matching runbook, create a fresh plan,
or destroy that layer in reverse order. Do not provision an expensive later
layer to work around an earlier defect.

The compatibility command `make layer` is plan-only. `APPLY=true make layer` is
rejected so a plan-only invocation can never masquerade as successful live proof.

Create `foundation`, `cluster`, `delivery`, `recovery`, `production`,
`automated-reaper`, `destructive-labs`, and `final-delete` GitHub environments.
Restrict every environment to `main`. Require a reviewer for human-initiated
apply, promotion, destructive, and final-delete paths. `automated-reaper` must
remain non-interactive so an expired lab cannot wait for approval.
