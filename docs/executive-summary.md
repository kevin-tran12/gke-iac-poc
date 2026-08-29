# Executive summary

This portfolio project closes the gap between knowing Kubernetes concepts and
operating a defensible Google Cloud platform. It provisions GKE bottom-up, proves
every dependency before advancing, releases a real asynchronous Go workload,
injects controlled failures, restores service and state, captures evidence, and
then removes all cost-producing resources.

The design favors managed GCP services where they teach a coherent production
pattern: Workload Identity instead of keys, Artifact Registry and Cloud Build for
supply chain, Cloud Deploy for verified promotion, Gateway API and Cloud Armor for
the edge, Pub/Sub/GCS for durable asynchronous processing, and Cloud Observability
for operations. Optional SQL, regional HA, NAT, and backup profiles stay isolated
so the core lab is understandable and short-lived.

The strongest result is not a live URL. It is a repeatable evidence chain from
commit and Terraform plan through tests, failure signals, recovery verification,
cost report, and independent zero-resource inventory.
