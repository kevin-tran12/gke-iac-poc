# Test strategy

Each layer runs five test classes: static, contract, negative, live integration,
and cleanup. Tests assert the outcome required by the next layer rather than the
existence of a Terraform resource.

Core journeys cover private cluster access, Workload Identity, registry pulls,
safe header forwarding, hello-app backend variation, readiness exclusion, HPA,
node autoscaling, authenticated asynchronous jobs, duplicate Pub/Sub delivery,
GCS idempotency, TLS, Cloud Armor, attestation denial, verified promotion, failed
rollout, Persistent Disk restore, SQL backup/PITR, and regional disruption.

Every failure lab follows:

```text
objective -> baseline -> hypothesis -> bounded injection -> detection
          -> recovery -> durable assertion -> evidence -> cleanup -> cost
```

Live tests skip without explicit environment variables. Load generators have hard
durations. Mutation scripts install cleanup traps before changing state. Terraform
reconciliation and an independent GCP inventory finish every run.
