# Layer 3: platform services

Creates Artifact Registry, Cloud Build identity, Pub/Sub with a dead-letter
topic, private result storage, Secret Manager resources, workload identities, and
optional private Cloud SQL. Secret values are intentionally added out of band by
an approved workflow so they never enter Terraform state.

The SQL path is disabled in `core` and enabled only by the `data` profile.
