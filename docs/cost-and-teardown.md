# Cost and teardown

This project optimizes for learning coverage, not free continuous hosting. Before
every apply, the operator records the current official prices and estimates the
profile's cluster hours, VM/disk time, load-balancer time, Armor requests, NAT
time/data, SQL time/storage, backups, builds, artifacts, logs, metrics, and egress.

The core profile caps the Spot pool at three total nodes, HPA at five Pods, raw results at
seven days, images at five recent versions, Flow Logs at 20% sampling, and the
whole environment at four hours. NAT, SQL, Backup for GKE, and regional HA are
separate approval-gated profiles.

Budgets detect spend; they do not stop it. The actual controls are hard capacity
limits, TTL gate records, an hourly reaper, reverse-order Terraform destroy, and
independent `gcloud` inventory. Runtime teardown removes recovery, edge, delivery,
workloads, addons, cluster, platform, and network in that order while retaining
the project, budget, WIF, audit configuration, and state. The separate
`final-delete.yml` workflow requires its own environment and the exact project ID
before it empties state, deletes the bucket, unlinks billing, and deletes the
project.

The zero-resource report fails if it finds clusters, VMs, forwarding rules,
addresses, disks, routers, SQL instances, DNS zones, Pub/Sub topics, secrets, or
Artifact Registry repositories.
