# Terraform IAM permission matrix

The four GitHub identities are phase boundaries, not generic administrators.
Every token must first pass the WIF checks for immutable repository and owner IDs,
`main`, the reviewed caller and reusable workflow, and the protected environment.
The state-bucket bindings limit each phase to its own writable state and
reviewed-plan prefixes. Cluster has read-only access to network/platform state;
delivery has read-only access to network/platform/cluster state so the gate
scripts can derive upstream outputs. Foundation, cluster, and delivery may read
prerequisite gate evidence but write only their own layer records; foundation
also owns the independent lab lease. Recovery retains full object access only so
partial and reverse-order teardown cannot be stranded.

| Identity | Intended scope | Required positive proof | Required negative proof |
| --- | --- | --- | --- |
| Foundation | Project controls and Layers 1–3 | `compute.networks.create` | no `container.clusters.create` |
| Cluster | Layers 4–6 | `container.clusters.create` | no `cloudkms.keyRings.create` |
| Delivery | Layers 7–8 and production promotion | `cloudkms.keyRings.create` | no `gkebackup.backupPlans.create` |
| Recovery | Layer 9, reverse-order destroy, and separately confirmed final deletion | `resourcemanager.projects.delete` | no use from an unapproved workflow or environment |

`scripts/gates/live/layer-01.sh` evaluates the permission rows with Policy
Troubleshooter. `.github/workflows/wif-negative-test.yml` must fail token exchange
because its workflow ref is intentionally absent from the provider allowlist.
For release evidence, also dispatch the approved live workflow from a non-`main`
ref and from a fork configured with the public provider name; both must be denied
before a Terraform command executes.

The recovery identity intentionally holds the union needed to delete runtime
resources. That is a conscious tradeoff: teardown remains reliable after a
partial failure, while exposure is constrained to recovery/teardown workflow and
environment claims. It is never used by pull-request CI or normal phase applies.

Foundation uses custom bucket- and project-control roles rather than project-wide
Storage Admin or Project Mover. It can configure platform buckets and update
project metadata but cannot read every object or move/delete the project.
Predefined admin roles remain where Terraform must create and delete varied
resource types; later layers should replace project roles with resource IAM as
the concrete resources become available.

The operator's initial ADC grants Foundation Billing Account User and Billing
Account Costs Manager. Those roles support project association and budget
management but cannot rewrite billing-account IAM. No GitHub identity receives
Billing Account Administrator. This makes the two billing-account bindings an
explicit bootstrap trust anchor: normal keyless runs can read them and manage the
budget, while changing or removing the bindings requires the billing-account
operator.
