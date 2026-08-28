# Cluster Terraform root

This root will own Google Cloud APIs, IAM, networking, the controlled container
registry path, GKE, and opt-in billable networking resources.

Provider versions and the Terraform CLI requirement will be selected from current
compatible releases, constrained in `versions.tf`, and recorded in the committed
`.terraform.lock.hcl`. No provider version has been assumed in the scaffold.

Planned outputs are limited to the values needed by the workload root. Long-lived
tokens, service-account keys, and private credentials must not be stored in state.

